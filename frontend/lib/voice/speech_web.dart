// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

html.SpeechRecognition? _activeRecognition;
String _lastRecognizedText = '';

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
