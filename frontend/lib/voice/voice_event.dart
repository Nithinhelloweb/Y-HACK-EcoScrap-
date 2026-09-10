abstract class VoiceEvent {}

class SpeechStartedEvent extends VoiceEvent {
  final DateTime timestamp;
  SpeechStartedEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

class SpeechStoppedEvent extends VoiceEvent {
  final DateTime timestamp;
  SpeechStoppedEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

class TranscriptionDeltaEvent extends VoiceEvent {
  final String textDelta;
  final bool isFinal;
  TranscriptionDeltaEvent({required this.textDelta, this.isFinal = false});
}

class ResponseStartedEvent extends VoiceEvent {
  final DateTime timestamp;
  ResponseStartedEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

class ResponseDeltaEvent extends VoiceEvent {
  final String textDelta;
  ResponseDeltaEvent({required this.textDelta});
}

class ResponseCompletedEvent extends VoiceEvent {
  final String fullText;
  final Map<String, dynamic>? uiPayload;
  ResponseCompletedEvent({required this.fullText, this.uiPayload});
}

class ToolExecutionEvent extends VoiceEvent {
  final String toolName;
  final Map<String, dynamic> parameters;
  final Map<String, dynamic>? result;
  ToolExecutionEvent({
    required this.toolName,
    this.parameters = const {},
    this.result,
  });
}

class BargeInEvent extends VoiceEvent {
  final DateTime timestamp;
  BargeInEvent({DateTime? timestamp}) : timestamp = timestamp ?? DateTime.now();
}

class VoiceErrorEvent extends VoiceEvent {
  final String message;
  VoiceErrorEvent({required this.message});
}
