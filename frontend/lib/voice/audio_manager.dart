import 'dart:async';
import 'package:flutter/foundation.dart';

import 'speech_web.dart'
    if (dart.library.io) 'speech_stub.dart';

class AudioManager with ChangeNotifier {
  bool _isRecording = false;
  bool _isPlaying = false;
  double _currentVolume = 0.0;
  Timer? _levelSimulatorTimer;

  String _currentTranscript = '';
  Uint8List? _lastRecordedAudioBytes;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  double get currentVolume => _currentVolume;
  String get currentTranscript => _currentTranscript;
  Uint8List? get lastRecordedAudioBytes => _lastRecordedAudioBytes;

  /// Starts listening / recording audio stream with live speech-to-text.
  void startRecording({
    String language = 'en',
    Function(double level)? onAudioLevel,
    Function(String transcript)? onTranscript,
  }) {
    _isRecording = true;
    _isPlaying = false;
    _currentTranscript = '';
    _lastRecordedAudioBytes = null;
    _startSimulatedLevel(onAudioLevel);

    // Real hardware microphone capture with Web Audio API analyser
    platformStartAudioRecording(
      onAudioLevel: (level) {
        _stopSimulatedLevel();
        _currentVolume = level;
        onAudioLevel?.call(level);
        notifyListeners();
      },
      onError: (err) {
        debugPrint('Audio recording error: $err');
      },
    );

    platformStartSpeechRecognition(
      language: language,
      onResult: (transcript, isFinal) {
        _currentTranscript = transcript;
        onTranscript?.call(transcript);
        notifyListeners();
      },
      onStart: () {
        notifyListeners();
      },
      onError: (err) {
        debugPrint('STT notice: $err');
      },
    );

    notifyListeners();
  }

  /// Stops recording audio and returns the final captured transcript.
  Future<String> stopRecording() async {
    _isRecording = false;
    _stopSimulatedLevel();

    try {
      _lastRecordedAudioBytes = await platformStopAudioRecording();
    } catch (e) {
      debugPrint('platformStopAudioRecording error: $e');
    }

    final finalText = platformStopSpeechRecognition();
    if (finalText.isNotEmpty) {
      _currentTranscript = finalText;
    }
    notifyListeners();
    return _currentTranscript;
  }

  /// Speaks text in the specified language ('en', 'ta', 'hi') using system/browser TTS.
  void speak(String text, {String language = 'en', VoidCallback? onComplete}) {
    platformSpeak(
      text: text,
      language: language,
      onStart: () {
        _isPlaying = true;
        notifyListeners();
      },
      onEnd: () {
        _isPlaying = false;
        notifyListeners();
        onComplete?.call();
      },
      onError: () {
        _isPlaying = false;
        notifyListeners();
        onComplete?.call();
      },
    );
  }

  /// Plays neural TTS audio from backend stream with automatic fallback to platform synthesis.
  void playAudioStream(
    String audioUrl, {
    String text = '',
    String language = 'en',
    VoidCallback? onComplete,
  }) {
    platformPlayAudioUrl(
      url: audioUrl,
      onStart: () {
        _isPlaying = true;
        notifyListeners();
      },
      onEnd: () {
        _isPlaying = false;
        notifyListeners();
        onComplete?.call();
      },
      onError: () {
        // Fallback to platform TTS if neural stream network fails
        speak(text, language: language, onComplete: onComplete);
      },
    );
  }

  /// Barge-in: immediately stops any speech playback.
  void stopPlayback() {
    platformStopSpeech();
    _isPlaying = false;
    notifyListeners();
  }

  void _startSimulatedLevel(Function(double level)? onAudioLevel) {
    _levelSimulatorTimer?.cancel();
    _levelSimulatorTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      // Pulsating sine-wave energy between 0.3 and 0.95
      final ms = DateTime.now().millisecondsSinceEpoch;
      final val = 0.4 + 0.5 * ((ms % 1000) / 1000.0);
      _currentVolume = val;
      onAudioLevel?.call(val);
      notifyListeners();
    });
  }

  void _stopSimulatedLevel() {
    _levelSimulatorTimer?.cancel();
    _currentVolume = 0.0;
  }

  @override
  void dispose() {
    stopPlayback();
    stopRecording();
    super.dispose();
  }
}
