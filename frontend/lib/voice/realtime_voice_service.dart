import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/voice_command.dart';

class RealtimeVoiceService {
  final String baseUrl;
  final String? authToken;

  RealtimeVoiceService({
    this.baseUrl = 'http://127.0.0.1:8000/api',
    this.authToken,
  });

  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      if (authToken != null) 'Authorization': 'Bearer $authToken',
    };
  }

  /// Creates an authenticated voice session on the backend.
  Future<VoiceSessionModel> createSession({
    String language = 'en',
    String inputMode = 'push_to_talk',
  }) async {
    final uri = Uri.parse('$baseUrl/voice/session');
    final response = await http.post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode({
        'language': language,
        'input_mode': inputMode,
      }),
    );

    if (response.statusCode == 200) {
      return VoiceSessionModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create voice session: ${response.body}');
    }
  }

  /// Sends spoken transcript turn and receives structured result and response.
  Future<VoiceCommandResult> sendVoiceCommand({
    required String text,
    String? languageHint,
    String? sessionId,
    bool? confirmed,
    Map<String, dynamic>? context,
  }) async {
    final uri = Uri.parse('$baseUrl/voice/command');
    final response = await http.post(
      uri,
      headers: _getHeaders(),
      body: jsonEncode({
        'text': text,
        'language_hint': ?languageHint,
        'session_id': ?sessionId,
        'confirmed': ?confirmed,
        'context': ?context,
      }),
    );

    if (response.statusCode == 200) {
      return VoiceCommandResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Voice command failed: ${response.body}');
    }
  }

  /// Fetches latest safety guidance for a given material.
  Future<Map<String, dynamic>> fetchSafetyGuidance(String material, {String lang = 'en'}) async {
    final uri = Uri.parse('$baseUrl/safety/$material?lang=$lang');
    final response = await http.get(uri, headers: _getHeaders());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    return {};
  }

  /// Transcribes recorded user audio using Groq Whisper model on the backend.
  Future<Map<String, dynamic>> transcribeAudio(
    List<int> audioBytes, {
    String filename = 'audio.wav',
    String? languageHint,
  }) async {
    final uri = Uri.parse('$baseUrl/voice/transcribe');
    final request = http.MultipartRequest('POST', uri);
    if (authToken != null) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }
    if (languageHint != null) {
      request.fields['language_hint'] = languageHint;
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: filename,
      ),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Audio transcription failed: ${response.body}');
    }
  }

  /// Builds the full streaming TTS audio URL for given text and language.
  String getTTSAudioUrl(String text, {String language = 'en'}) {
    final encodedText = Uri.encodeComponent(text);
    return '$baseUrl/voice/tts?text=$encodedText&language=$language';
  }

  /// Fetches streaming TTS MP3 audio bytes directly.
  Future<List<int>> fetchTTSAudio(String text, {String language = 'en'}) async {
    final uri = Uri.parse(getTTSAudioUrl(text, language: language));
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('TTS audio fetch failed with status ${response.statusCode}');
    }
  }
}
