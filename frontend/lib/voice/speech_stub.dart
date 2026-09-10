import 'dart:async';
import 'package:flutter/foundation.dart';

bool platformIsSpeechRecognitionSupported() => false;

void platformStartSpeechRecognition({
  required String language,
  required Function(String transcript, bool isFinal) onResult,
  VoidCallback? onStart,
  VoidCallback? onEnd,
  Function(String error)? onError,
}) {
  onStart?.call();
}

String platformStopSpeechRecognition() {
  return '';
}

void platformSpeak({
  required String text,
  required String language,
  VoidCallback? onStart,
  VoidCallback? onEnd,
  VoidCallback? onError,
}) {
  onStart?.call();
  Timer(const Duration(milliseconds: 1000), () {
    onEnd?.call();
  });
}

void platformPlayAudioUrl({
  required String url,
  VoidCallback? onStart,
  VoidCallback? onEnd,
  VoidCallback? onError,
}) {
  onStart?.call();
  Timer(const Duration(milliseconds: 600), () {
    onEnd?.call();
  });
}

void platformStopSpeech() {
  // No-op on stub
}
