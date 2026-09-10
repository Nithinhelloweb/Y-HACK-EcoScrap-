import '../models/voice_command.dart';

enum VoiceStatus {
  idle,
  listening,
  processing,
  executing,
  speaking,
  error,
  offline,
}

extension VoiceStatusExtension on VoiceStatus {
  String get displayName {
    switch (this) {
      case VoiceStatus.idle:
        return 'IDLE';
      case VoiceStatus.listening:
        return 'LISTENING';
      case VoiceStatus.processing:
        return 'PROCESSING';
      case VoiceStatus.executing:
        return 'EXECUTING';
      case VoiceStatus.speaking:
        return 'SPEAKING';
      case VoiceStatus.error:
        return 'ERROR';
      case VoiceStatus.offline:
        return 'OFFLINE';
    }
  }

  String get guidanceText {
    switch (this) {
      case VoiceStatus.idle:
        return 'Tap or hold mic to speak';
      case VoiceStatus.listening:
        return 'Listening... Speak naturally';
      case VoiceStatus.processing:
        return 'Understanding speech & intent...';
      case VoiceStatus.executing:
        return 'Executing EcoScrap function...';
      case VoiceStatus.speaking:
        return 'Assistant speaking...';
      case VoiceStatus.error:
        return 'An error occurred. Try again.';
      case VoiceStatus.offline:
        return 'Offline Mode: Local commands active';
    }
  }
}

class VoiceSessionState {
  final VoiceStatus status;
  final String detectedLanguage;
  final String liveTranscription;
  final String assistantResponse;
  final String? activeIntent;
  final List<VoiceEntityItem> detectedEntities;
  final double? weightKg;
  final String? executedAction;
  final Map<String, dynamic>? executedResult;
  final bool requiresConfirmation;
  final String? confirmationPrompt;
  final String? errorMessage;
  final bool isHandsFree;
  final double audioLevel; // 0.0 to 1.0 for waveform animation

  const VoiceSessionState({
    this.status = VoiceStatus.idle,
    this.detectedLanguage = 'en',
    this.liveTranscription = '',
    this.assistantResponse = 'Hello! Tell me what e-waste you collected.',
    this.activeIntent,
    this.detectedEntities = const [],
    this.weightKg,
    this.executedAction,
    this.executedResult,
    this.requiresConfirmation = false,
    this.confirmationPrompt,
    this.errorMessage,
    this.isHandsFree = false,
    this.audioLevel = 0.0,
  });

  VoiceSessionState copyWith({
    VoiceStatus? status,
    String? detectedLanguage,
    String? liveTranscription,
    String? assistantResponse,
    String? activeIntent,
    List<VoiceEntityItem>? detectedEntities,
    double? weightKg,
    String? executedAction,
    Map<String, dynamic>? executedResult,
    bool? requiresConfirmation,
    String? confirmationPrompt,
    String? errorMessage,
    bool? isHandsFree,
    double? audioLevel,
  }) {
    return VoiceSessionState(
      status: status ?? this.status,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      liveTranscription: liveTranscription ?? this.liveTranscription,
      assistantResponse: assistantResponse ?? this.assistantResponse,
      activeIntent: activeIntent ?? this.activeIntent,
      detectedEntities: detectedEntities ?? this.detectedEntities,
      weightKg: weightKg ?? this.weightKg,
      executedAction: executedAction ?? this.executedAction,
      executedResult: executedResult ?? this.executedResult,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      confirmationPrompt: confirmationPrompt ?? this.confirmationPrompt,
      errorMessage: errorMessage ?? this.errorMessage,
      isHandsFree: isHandsFree ?? this.isHandsFree,
      audioLevel: audioLevel ?? this.audioLevel,
    );
  }
}
