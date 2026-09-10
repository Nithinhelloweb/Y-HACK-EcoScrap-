// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

html.SpeechRecognition? _activeRecognition;
String _lastRecognizedText = '';

html.MediaRecorder? _mediaRecorder;
List<html.Blob> _audioChunks = [];
html.MediaStream? _mediaStream;
dynamic _audioContext;
Timer? _audioLevelTimer;

Future<void> platformStartAudioRecording({
  Function(double level)? onAudioLevel,
  Function(String error)? onError,
}) async {
  try {
    final mediaDevices = html.window.navigator.mediaDevices;
    if (mediaDevices == null) {
      onError?.call('Microphone media devices not supported.');
      return;
    }

    final stream = await mediaDevices.getUserMedia({'audio': true});
    _mediaStream = stream;
    _audioChunks = [];

    // Real audio frequency / energy tracking via Web Audio AnalyserNode
    try {
      final audioCtxConstructor = js.context['AudioContext'] ?? js.context['webkitAudioContext'];
      if (audioCtxConstructor != null) {
        final audioCtx = js.JsObject(audioCtxConstructor);
        _audioContext = audioCtx;
        final source = audioCtx.callMethod('createMediaStreamSource', [stream]);
        final analyser = audioCtx.callMethod('createAnalyser');
        analyser['fftSize'] = 256;
        source.callMethod('connect', [analyser]);

        final bufferLength = analyser['frequencyBinCount'] as int? ?? 128;
        final dataArray = Uint8List(bufferLength);

        _audioLevelTimer?.cancel();
        _audioLevelTimer = Timer.periodic(const Duration(milliseconds: 60), (t) {
          if (_mediaRecorder == null) {
            t.cancel();
            return;
          }
          analyser.callMethod('getByteFrequencyData', [dataArray]);
          double sum = 0;
          for (int i = 0; i < dataArray.length; i++) {
            sum += dataArray[i];
          }
          final rawAvg = sum / (dataArray.length * 255.0);
          final level = math.min(1.0, math.max(0.0, rawAvg * 3.5));
          onAudioLevel?.call(level);
        });
      }
    } catch (e) {
      debugPrint('AudioContext setup error: $e');
    }

    // MediaRecorder for capturing raw audio bytes
    String mimeType = 'audio/webm';
    if (!html.MediaRecorder.isTypeSupported('audio/webm')) {
      if (html.MediaRecorder.isTypeSupported('audio/mp4')) {
        mimeType = 'audio/mp4';
      } else {
        mimeType = '';
      }
    }

    final recorder = mimeType.isNotEmpty
        ? html.MediaRecorder(stream, {'mimeType': mimeType})
        : html.MediaRecorder(stream);

    recorder.addEventListener('dataavailable', (html.Event event) {
      final blobEvent = event as dynamic;
      final data = blobEvent.data as html.Blob?;
      if (data != null && data.size > 0) {
        _audioChunks.add(data);
      }
    });

    recorder.start(100);
    _mediaRecorder = recorder;
  } catch (e) {
    debugPrint('Microphone stream access error: $e');
    onError?.call(e.toString());
  }
}

Future<Uint8List?> platformStopAudioRecording() async {
  try {
    _audioLevelTimer?.cancel();
    _audioLevelTimer = null;

    final recorder = _mediaRecorder;
    _mediaRecorder = null;

    final stream = _mediaStream;
    _mediaStream = null;

    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }

    if (_audioContext != null) {
      try {
        _audioContext.callMethod('close');
      } catch (_) {}
      _audioContext = null;
    }

    if (recorder != null) {
      final completer = Completer<void>();
      recorder.addEventListener('stop', (_) {
        if (!completer.isCompleted) completer.complete();
      });

      if (recorder.state != 'inactive') {
        recorder.stop();
      }

      await completer.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      );
    }

    if (_audioChunks.isNotEmpty) {
      final combinedBlob = html.Blob(_audioChunks);
      _audioChunks = [];

      final reader = html.FileReader();
      reader.readAsArrayBuffer(combinedBlob);
      await reader.onLoad.first;

      final res = reader.result;
      if (res is ByteBuffer) {
        return res.asUint8List();
      } else if (res is Uint8List) {
        return res;
      }
    }
  } catch (e) {
    debugPrint('Error finalizing microphone audio: $e');
  }
  return null;
}

bool platformIsSpeechRecognitionSupported() {
  try {
    return html.SpeechRecognition.supported;
  } catch (_) {
    return false;
  }
}

void platformStartSpeechRecognition({
  required String language,
  required Function(String transcript, bool isFinal) onResult,
  VoidCallback? onStart,
  VoidCallback? onEnd,
  Function(String error)? onError,
}) {
  try {
    if (!html.SpeechRecognition.supported) {
      onError?.call('Web Speech Recognition is not supported in this browser.');
      return;
    }

    try {
      _activeRecognition?.abort();
    } catch (_) {}
    _lastRecognizedText = '';

    final recognition = html.SpeechRecognition();
    recognition.continuous = true;
    recognition.interimResults = true;

    if (language == 'ta') {
      recognition.lang = 'ta-IN';
    } else if (language == 'hi') {
      recognition.lang = 'hi-IN';
    } else {
      recognition.lang = 'en-US';
    }

    recognition.onStart.listen((_) {
      onStart?.call();
    });

    recognition.onResult.listen((event) {
      final results = event.results;
      if (results != null && results.isNotEmpty) {
        final sb = StringBuffer();
        bool hasFinal = false;
        for (var i = 0; i < results.length; i++) {
          final res = results[i];
          final len = res.length ?? 0;
          if (len > 0) {
            final alt = res.item(0);
            final t = alt.transcript;
            if (t != null && t.isNotEmpty) {
              sb.write(t);
            }
            if (res.isFinal == true) {
              hasFinal = true;
            }
          }
        }
        final text = sb.toString().trim();
        if (text.isNotEmpty) {
          _lastRecognizedText = text;
          onResult(text, hasFinal);
        }
      }
    });

    recognition.onError.listen((e) {
      final errorMsg = e.error?.toString() ?? 'Microphone speech recognition error';
      debugPrint('SpeechRecognition error: $errorMsg');
      onError?.call(errorMsg);
    });

    recognition.onEnd.listen((_) {
      onEnd?.call();
    });

    recognition.start();
    _activeRecognition = recognition;
  } catch (e) {
    debugPrint('Failed to start SpeechRecognition: $e');
    onError?.call(e.toString());
  }
}

String platformStopSpeechRecognition() {
  try {
    _activeRecognition?.stop();
  } catch (_) {}
  _activeRecognition = null;
  return _lastRecognizedText;
}

void platformSpeak({
  required String text,
  required String language,
  VoidCallback? onStart,
  VoidCallback? onEnd,
  VoidCallback? onError,
}) {
  try {
    final synth = html.window.speechSynthesis;
    if (synth != null) {
      synth.cancel(); // Barge-in: interrupt any previous speech
      final utterance = html.SpeechSynthesisUtterance(text);

      if (language == 'ta') {
        utterance.lang = 'ta-IN';
      } else if (language == 'hi') {
        utterance.lang = 'hi-IN';
      } else {
        utterance.lang = 'en-US';
      }

      utterance.rate = 1.0;
      utterance.pitch = 1.0;

      onStart?.call();

      utterance.onEnd.listen((_) {
        onEnd?.call();
      });

      utterance.onError.listen((_) {
        onError?.call();
      });

      synth.speak(utterance);
      return;
    }
  } catch (e) {
    debugPrint('Web SpeechSynthesis error: $e');
  }
  onError?.call();
}

html.AudioElement? _currentAudioElement;

void platformPlayAudioUrl({
  required String url,
  VoidCallback? onStart,
  VoidCallback? onEnd,
  VoidCallback? onError,
}) {
  try {
    _currentAudioElement?.pause();
    _currentAudioElement = html.AudioElement(url);
    onStart?.call();

    _currentAudioElement!.onEnded.listen((_) {
      onEnd?.call();
    });

    _currentAudioElement!.onError.listen((_) {
      onError?.call();
    });

    _currentAudioElement!.play();
  } catch (e) {
    debugPrint('Web Audio playback error: $e');
    onError?.call();
  }
}

void platformStopSpeech() {
  try {
    _currentAudioElement?.pause();
    _currentAudioElement = null;
    html.window.speechSynthesis?.cancel();
  } catch (_) {}
}
