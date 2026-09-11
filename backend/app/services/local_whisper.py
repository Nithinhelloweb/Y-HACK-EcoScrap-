import os
import sys
import tempfile
import threading
import logging
from typing import Optional, Dict, Any, Union

logger = logging.getLogger("ecoscrap.whisper")
logging.basicConfig(level=logging.INFO)

_model_lock = threading.Lock()
_whisper_model = None
_whisper_accelerator = "Uninitialized"
_MODEL_NAME = os.getenv("LOCAL_WHISPER_MODEL", "tiny")

def get_whisper_accelerator_info() -> Dict[str, Any]:
    """Returns telemetry on the active Whisper model and GPU accelerator."""
    global _whisper_accelerator
    if _whisper_model is None:
        try:
            get_whisper_model()
        except Exception:
            pass
    return {
        "model_name": _MODEL_NAME,
        "accelerator": _whisper_accelerator,
        "is_gpu_accelerated": "CUDA" in _whisper_accelerator or "GPU" in _whisper_accelerator
    }

def get_whisper_model():
    """
    Returns the loaded local Whisper model instance (singleton).
    Automatically leverages NVIDIA RTX GPU (CUDA) when available,
    with graceful fallback to CPU. Thread-safe initialization.
    """
    global _whisper_model, _whisper_accelerator
    if _whisper_model is None:
        with _model_lock:
            if _whisper_model is None:
                try:
                    import torch
                    import whisper

                    prefer_cuda = os.getenv("DISABLE_GPU_WHISPER", "0") != "1"
                    if prefer_cuda and torch.cuda.is_available():
                        device_name = torch.cuda.get_device_name(0)
                        logger.info(f"Loading local Whisper model '{_MODEL_NAME}' on CUDA GPU: {device_name}...")
                        try:
                            # Avoid cuDNN 9 Windows engine lookup glitches by leveraging PyTorch native CUDA kernels
                            torch.backends.cudnn.enabled = False
                            _whisper_model = whisper.load_model(_MODEL_NAME, device="cuda")
                            _whisper_accelerator = f"CUDA (GPU: {device_name})"
                            logger.info(f"Local Whisper model '{_MODEL_NAME}' loaded on {_whisper_accelerator}.")
                            
                            # Warmup run to compile CUDA kernels upfront
                            try:
                                import numpy as np
                                dummy_audio = np.zeros(16000, dtype=np.float32)
                                _whisper_model.transcribe(dummy_audio, fp16=False, verbose=False)
                                logger.info(f"Whisper CUDA warmup completed successfully on {_whisper_accelerator}.")
                            except Exception as warmup_err:
                                logger.warning(f"Whisper warmup notice: {warmup_err}")
                        except Exception as cuda_init_err:
                            logger.warning(f"CUDA initialization failed ({cuda_init_err}), falling back to CPU...")
                            _whisper_model = whisper.load_model(_MODEL_NAME, device="cpu")
                            _whisper_accelerator = "CPU (Fallback)"
                    else:
                        logger.info(f"Loading local Whisper model '{_MODEL_NAME}' on CPU...")
                        _whisper_model = whisper.load_model(_MODEL_NAME, device="cpu")
                        _whisper_accelerator = "CPU"
                    logger.info(f"Local Whisper model '{_MODEL_NAME}' ready on {_whisper_accelerator}.")
                except Exception as e:
                    logger.error(f"Failed to load local Whisper model: {e}")
                    raise
    return _whisper_model

def transcribe_audio_local(
    audio_data: Union[str, bytes],
    language_hint: Optional[str] = None
) -> Dict[str, Any]:
    """
    Transcribes audio using the local OpenAI Whisper model.
    Accelerated with NVIDIA GPU (CUDA) when available, with automatic CPU fallback.
    Accepts either an audio file path (str) or raw audio bytes (bytes).
    Returns a dict with 'text', 'detected_language', 'confidence', and 'accelerator'.
    """
    temp_path = None
    try:
        if isinstance(audio_data, bytes):
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
                tmp.write(audio_data)
                temp_path = tmp.name
            audio_path = temp_path
        else:
            audio_path = audio_data

        model = get_whisper_model()
        is_cuda = "CUDA" in _whisper_accelerator or (hasattr(model, "device") and str(model.device).startswith("cuda"))

        # Whisper inference options (fp16=False provides optimal speed and cuDNN 9 stability on RTX 3050)
        options: Dict[str, Any] = {
            "fp16": False,
            "verbose": False
        }
        if language_hint and language_hint in ["en", "ta", "hi"]:
            options["language"] = language_hint

        try:
            if is_cuda:
                import torch
                torch.backends.cudnn.enabled = False
            result = model.transcribe(audio_path, **options)
        except Exception as run_err:
            if is_cuda:
                logger.warning(f"GPU inference glitch ({run_err}), retrying on CPU fallback...")
                import whisper
                cpu_model = whisper.load_model(_MODEL_NAME, device="cpu")
                options["fp16"] = False
                result = cpu_model.transcribe(audio_path, **options)
            else:
                raise

        raw_text = (result.get("text") or "").strip()
        detected_lang = result.get("language") or "en"
        
        # Normalize language code to 'en', 'ta', 'hi'
        lang_str = str(detected_lang).lower()
        if "tamil" in lang_str or lang_str == "ta":
            norm_lang = "ta"
        elif "hindi" in lang_str or lang_str == "hi":
            norm_lang = "hi"
        else:
            norm_lang = "en"

        return {
            "text": raw_text,
            "detected_language": norm_lang,
            "confidence": 0.98 if raw_text else 0.50,
            "model": f"whisper-{_MODEL_NAME}-gpu" if is_cuda else f"whisper-{_MODEL_NAME}-cpu",
            "accelerator": _whisper_accelerator
        }
    except Exception as e:
        logger.error(f"Local Whisper transcription error: {e}")
        raise
    finally:
        if temp_path and os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception:
                pass
