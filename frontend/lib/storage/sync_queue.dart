import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QueuedVoiceAction {
  final String id;
  final String rawText;
  final String? intent;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  QueuedVoiceAction({
    required this.id,
    required this.rawText,
    this.intent,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'raw_text': rawText,
        'intent': intent,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };

  factory QueuedVoiceAction.fromJson(Map<String, dynamic> json) =>
      QueuedVoiceAction(
        id: json['id'] as String,
        rawText: json['raw_text'] as String,
        intent: json['intent'] as String?,
        payload: json['payload'] as Map<String, dynamic>? ?? {},
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class SyncQueue with ChangeNotifier {
  static const String _storageKey = 'ecoscrap_offline_voice_queue';
  final List<QueuedVoiceAction> _actions = [];

  List<QueuedVoiceAction> get actions => List.unmodifiable(_actions);
  int get pendingCount => _actions.length;

  Future<void> loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final List decoded = jsonDecode(data);
        _actions.clear();
        for (final item in decoded) {
          _actions.add(QueuedVoiceAction.fromJson(item));
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading voice sync queue: $e');
    }
  }

  Future<void> enqueue({
    required String rawText,
    String? intent,
    required Map<String, dynamic> payload,
  }) async {
    final action = QueuedVoiceAction(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      rawText: rawText,
      intent: intent,
      payload: payload,
      timestamp: DateTime.now(),
    );
    _actions.add(action);
    await _save();
    notifyListeners();
  }

  Future<QueuedVoiceAction?> dequeue() async {
    if (_actions.isEmpty) return null;
    final act = _actions.removeAt(0);
    await _save();
    notifyListeners();
    return act;
  }

  Future<void> clear() async {
    _actions.clear();
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = jsonEncode(_actions.map((a) => a.toJson()).toList());
      await prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('Error saving voice sync queue: $e');
    }
  }
}
