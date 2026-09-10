import 'dart:async';
import 'package:flutter/material.dart';

import '../models/voice_command.dart';
import '../storage/sync_queue.dart';
import 'audio_manager.dart';
import 'realtime_voice_service.dart';
import 'voice_state.dart';

class VoiceController with ChangeNotifier {
  final RealtimeVoiceService voiceService;
  final AudioManager audioManager;
  final SyncQueue syncQueue;

  VoiceSessionState _state = const VoiceSessionState();
  VoiceSessionModel? _activeSession;
  String _selectedLanguage = 'en'; // 'en', 'ta', 'hi'

  VoiceSessionState get state => _state;
  VoiceSessionModel? get activeSession => _activeSession;
  String get selectedLanguage => _selectedLanguage;

  VoiceController({
    required this.voiceService,
    required this.audioManager,
    required this.syncQueue,
  }) {
    audioManager.addListener(_onAudioStateChanged);
  }

  void _onAudioStateChanged() {
    if (audioManager.isRecording) {
      _state = _state.copyWith(
        status: VoiceStatus.listening,
        audioLevel: audioManager.currentVolume,
      );
      notifyListeners();
    } else if (audioManager.isPlaying) {
      _state = _state.copyWith(
        status: VoiceStatus.speaking,
      );
      notifyListeners();
    }
  }

  /// Initializes the voice session with the backend.
  Future<void> initSession({String language = 'en'}) async {
    _selectedLanguage = language;
    _state = _state.copyWith(
      status: VoiceStatus.idle,
      detectedLanguage: language,
      assistantResponse: _getWelcomeMessage(language),
    );
    notifyListeners();

    try {
      final session = await voiceService.createSession(language: language);
      _activeSession = session;
    } catch (e) {
      debugPrint('Session initialization failed (operating in offline fallback): $e');
      _state = _state.copyWith(
        status: VoiceStatus.idle,
        errorMessage: 'Connected in local mode.',
      );
      notifyListeners();
    }
  }

  String _getWelcomeMessage(String lang) {
    if (lang == 'ta') {
      return 'வணக்கம்! நீங்கள் என்ன மின்-கழிவுகளை சேகரித்துள்ளீர்கள் என்று கூறுங்கள்.';
    } else if (lang == 'hi') {
      return 'नमस्ते! आपने किस प्रकार का ई-कचरा एकत्र किया है, मुझे बताएं।';
    }
    return 'Hello! Tell me what e-waste you collected, ask prices, or check safety.';
  }

  void setLanguage(String lang) {
    _selectedLanguage = lang;
    _state = _state.copyWith(
      detectedLanguage: lang,
      assistantResponse: _getWelcomeMessage(lang),
    );
    notifyListeners();
  }

  void toggleHandsFree(bool value) {
    _state = _state.copyWith(isHandsFree: value);
    notifyListeners();
  }

  /// Press-and-hold Push-To-Talk: Start listening
  void onMicPress() {
    audioManager.stopPlayback(); // Barge-in interruption!
    _state = _state.copyWith(
      status: VoiceStatus.listening,
      liveTranscription: 'Listening... (Speak now)',
      errorMessage: null,
    );
    notifyListeners();

    audioManager.startRecording(
      language: _selectedLanguage,
      onTranscript: (liveText) {
        if (liveText.trim().isNotEmpty) {
          _state = _state.copyWith(
            liveTranscription: liveText,
            status: VoiceStatus.listening,
          );
          notifyListeners();
        }
      },
    );
  }

  /// Release Push-To-Talk: Send captured speech
  Future<void> onMicRelease({String? spokenTranscript}) async {
    final captured = audioManager.stopRecording();
    _state = _state.copyWith(
      status: VoiceStatus.processing,
      audioLevel: 0.0,
    );
    notifyListeners();

    String text = (spokenTranscript ?? (captured.isNotEmpty ? captured : _state.liveTranscription)).trim();
    if (text == 'Listening... (Speak now)' || text == 'Listening...') {
      text = captured.trim();
    }

    if (text.isEmpty) {
      _state = _state.copyWith(
        status: VoiceStatus.idle,
        liveTranscription: '',
        errorMessage: 'Tap and hold to speak, or use demo prompts below.',
      );
      notifyListeners();
      return;
    }

    _state = _state.copyWith(
      status: VoiceStatus.processing,
      liveTranscription: text,
    );
    notifyListeners();

    await processSpokenText(text);
  }

  /// Sends text to the voice turn processor.
  Future<void> processSpokenText(
    String text, {
    bool? confirmed,
    Map<String, dynamic>? extraContext,
  }) async {
    _state = _state.copyWith(
      status: VoiceStatus.processing,
      liveTranscription: text,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final context = {
        ...?extraContext,
        if (_state.activeIntent != null) 'intent': _state.activeIntent,
        if (_state.detectedEntities.isNotEmpty)
          'items': _state.detectedEntities.map((e) => {'name': e.name, 'quantity': e.quantity, 'normalized_type': e.normalizedType, 'unit': e.unit}).toList(),
        if (_state.weightKg != null) 'weight_kg': _state.weightKg,
        if (_state.requiresConfirmation) 'pending_confirmation': true,
      };

      final result = await voiceService.sendVoiceCommand(
        text: text,
        languageHint: _selectedLanguage,
        sessionId: _activeSession?.sessionId,
        confirmed: confirmed,
        context: context,
      );

      _state = _state.copyWith(
        status: result.actionExecuted != null ? VoiceStatus.executing : VoiceStatus.speaking,
        detectedLanguage: result.detectedLanguage,
        assistantResponse: result.spokenResponse,
        activeIntent: result.intent,
        detectedEntities: result.items.isNotEmpty ? result.items : _state.detectedEntities,
        weightKg: result.weightKg ?? _state.weightKg,
        executedAction: result.actionExecuted,
        executedResult: result.actionResult,
        requiresConfirmation: result.requiresConfirmation,
        confirmationPrompt: result.confirmationPrompt,
      );
      notifyListeners();

      // Speak response aloud via neural audio stream or platform TTS
      if (result.audioUrl != null && result.audioUrl!.isNotEmpty) {
        final fullAudioUrl = result.audioUrl!.startsWith('http')
            ? result.audioUrl!
            : '${voiceService.baseUrl.replaceAll("/api", "")}${result.audioUrl}';
        audioManager.playAudioStream(
          fullAudioUrl,
          text: result.spokenResponse,
          language: result.detectedLanguage,
          onComplete: () {
            _state = _state.copyWith(status: VoiceStatus.idle);
            notifyListeners();
          },
        );
      } else {
        audioManager.speak(
          result.spokenResponse,
          language: result.detectedLanguage,
          onComplete: () {
            _state = _state.copyWith(status: VoiceStatus.idle);
            notifyListeners();
          },
        );
      }
    } catch (e) {
      debugPrint('Voice processing error (queueing to sync queue): $e');
      // Offline fallback
      await syncQueue.enqueue(
        rawText: text,
        intent: 'PENDING_OFFLINE',
        payload: {'text': text, 'language': _selectedLanguage},
      );

      final fallbackMsg = _selectedLanguage == 'ta'
          ? 'இணைப்பு இல்லை. உங்கள் செயல் ஆஃப்லைனில் பாதுகாக்கப்பட்டது.'
          : 'Network unavailable. Command saved locally and queued for sync.';

      _state = _state.copyWith(
        status: VoiceStatus.offline,
        assistantResponse: fallbackMsg,
        errorMessage: 'Saved to offline queue.',
      );
      notifyListeners();

      audioManager.speak(fallbackMsg, language: _selectedLanguage, onComplete: () {
        _state = _state.copyWith(status: VoiceStatus.idle);
        notifyListeners();
      });
    }
  }

  /// User confirms an action via UI button or affirmative speech.
  Future<void> confirmAction() async {
    await processSpokenText('yes', confirmed: true, extraContext: {'pending_confirmation': true});
  }

  /// User cancels pending action.
  void cancelAction() {
    _state = _state.copyWith(
      status: VoiceStatus.idle,
      requiresConfirmation: false,
      confirmationPrompt: null,
      assistantResponse: 'Action cancelled.',
    );
    notifyListeners();
  }

  /// Transcribes spoken audio bytes using Groq Whisper, then processes the conversational turn.
  Future<void> processAudioBytes(List<int> audioBytes, {String filename = 'mic.wav'}) async {
    _state = _state.copyWith(
      status: VoiceStatus.processing,
      liveTranscription: 'Transcribing speech...',
      errorMessage: null,
    );
    notifyListeners();

    try {
      final transcriptionResult = await voiceService.transcribeAudio(
        audioBytes,
        filename: filename,
        languageHint: _selectedLanguage,
      );
      final text = transcriptionResult['text'] as String? ?? '';
      final detectedLang = transcriptionResult['detected_language'] as String? ?? _selectedLanguage;
      if (text.isNotEmpty) {
        _selectedLanguage = detectedLang;
        await processSpokenText(text);
      } else {
        _state = _state.copyWith(
          status: VoiceStatus.idle,
          liveTranscription: '',
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Transcription error: $e');
      _state = _state.copyWith(
        status: VoiceStatus.idle,
        errorMessage: 'Transcription error: $e',
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    audioManager.removeListener(_onAudioStateChanged);
    super.dispose();
  }
}
