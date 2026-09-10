class VoiceEntityItem {
  final String name;
  final String normalizedType;
  final double quantity;
  final String unit;

  VoiceEntityItem({
    required this.name,
    required this.normalizedType,
    required this.quantity,
    this.unit = 'units',
  });

  factory VoiceEntityItem.fromJson(Map<String, dynamic> json) {
    return VoiceEntityItem(
      name: json['name'] as String? ?? '',
      normalizedType: json['normalized_type'] as String? ?? 'UNKNOWN',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'units',
    );
  }
}

class VoiceCommandResult {
  final String intent;
  final String detectedLanguage;
  final List<VoiceEntityItem> items;
  final double? weightKg;
  final List<String> missingFields;
  final String spokenResponse;
  final String? actionExecuted;
  final Map<String, dynamic>? actionResult;
  final bool requiresConfirmation;
  final String? confirmationPrompt;
  final Map<String, dynamic>? uiPayload;
  final String? sessionId;

  final String? audioUrl;

  VoiceCommandResult({
    required this.intent,
    required this.detectedLanguage,
    this.items = const [],
    this.weightKg,
    this.missingFields = const [],
    required this.spokenResponse,
    this.actionExecuted,
    this.actionResult,
    this.requiresConfirmation = false,
    this.confirmationPrompt,
    this.uiPayload,
    this.sessionId,
    this.audioUrl,
  });

  factory VoiceCommandResult.fromJson(Map<String, dynamic> json) {
    final entities = json['entities'] as Map<String, dynamic>? ?? {};
    final rawItems = (entities['items'] as List<dynamic>? ?? []);
    final itemsList = rawItems
        .map((i) => VoiceEntityItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return VoiceCommandResult(
      intent: json['intent'] as String? ?? 'HELP',
      detectedLanguage: json['detected_language'] as String? ?? 'en',
      items: itemsList,
      weightKg: (entities['weight_kg'] as num?)?.toDouble(),
      missingFields: (json['missing_fields'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      spokenResponse: json['spoken_response'] as String? ?? '',
      actionExecuted: json['action_executed'] as String?,
      actionResult: json['action_result'] as Map<String, dynamic>?,
      requiresConfirmation: json['requires_confirmation'] as bool? ?? false,
      confirmationPrompt: json['confirmation_prompt'] as String?,
      uiPayload: json['ui_payload'] as Map<String, dynamic>?,
      sessionId: json['session_id'] as String?,
      audioUrl: json['audio_url'] as String?,
    );
  }
}

class VoiceSessionModel {
  final String sessionId;
  final String sessionToken;
  final String userId;
  final String? collectorId;
  final String language;
  final String inputMode;
  final String status;
  final DateTime expiresAt;
  final List<Map<String, dynamic>> toolManifest;
  final Map<String, dynamic>? openaiRealtimeConfig;

  VoiceSessionModel({
    required this.sessionId,
    required this.sessionToken,
    required this.userId,
    this.collectorId,
    required this.language,
    required this.inputMode,
    required this.status,
    required this.expiresAt,
    this.toolManifest = const [],
    this.openaiRealtimeConfig,
  });

  factory VoiceSessionModel.fromJson(Map<String, dynamic> json) {
    return VoiceSessionModel(
      sessionId: json['session_id'] as String? ?? '',
      sessionToken: json['session_token'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      collectorId: json['collector_id'] as String?,
      language: json['language'] as String? ?? 'en',
      inputMode: json['input_mode'] as String? ?? 'push_to_talk',
      status: json['status'] as String? ?? 'ACTIVE',
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      toolManifest: (json['tool_manifest'] as List<dynamic>? ?? [])
          .map((t) => t as Map<String, dynamic>)
          .toList(),
      openaiRealtimeConfig: json['openai_realtime_config'] as Map<String, dynamic>?,
    );
  }
}
