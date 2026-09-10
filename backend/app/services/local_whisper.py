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
_MODEL_NAME = os.getenv("LOCAL_WHISPER_MODEL", "tiny")

def get_whisper_model():
    """
    Returns the loaded local Whisper model instance (singleton).
    Thread-safe initialization.
    """
    global _whisper_model
    if _whisper_model is None:
        with _model_lock:
            if _whisper_model is None:
                try:
                    import whisper
                    logger.info(f"Loading local Whisper model: '{_MODEL_NAME}' on CPU...")
                    _whisper_model = whisper.load_model(_MODEL_NAME, device="cpu")
                    logger.info(f"Local Whisper model '{_MODEL_NAME}' loaded successfully.")
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
    Accepts either an audio file path (str) or raw audio bytes (bytes).
    Returns a dict with 'text', 'detected_language', and 'confidence'.
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
        
        # Whisper options
        options = {
            "fp16": False,
            "verbose": False
        }
        if language_hint and language_hint in ["en", "ta", "hi"]:
            options["language"] = language_hint

        result = model.transcribe(audio_path, **options)
        
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
            "model": f"whisper-{_MODEL_NAME}-local"
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
