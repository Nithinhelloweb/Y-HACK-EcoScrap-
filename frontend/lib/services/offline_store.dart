import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lot_model.dart';
import 'api_service.dart';

class OfflineStore extends ChangeNotifier {
  static const String _outboxKey = 'ecoscrap_outbox';
  
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  final List<LotModel> _inMemoryLots = [];
  List<LotModel> get lots => List.unmodifiable(_inMemoryLots);

  final List<Map<String, dynamic>> _pendingOutbox = [];
  List<Map<String, dynamic>> get pendingOutbox => List.unmodifiable(_pendingOutbox);

  int get pendingCount => _pendingOutbox.length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final rawOutbox = prefs.getStringList(_outboxKey) ?? [];
    _pendingOutbox.clear();
    for (final item in rawOutbox) {
      _pendingOutbox.add(jsonDecode(item) as Map<String, dynamic>);
    }
    notifyListeners();
  }

  void toggleOfflineMode() {
    _isOfflineMode = !_isOfflineMode;
    notifyListeners();
  }

  void setLots(List<LotModel> newLots) {
    _inMemoryLots.clear();
    _inMemoryLots.addAll(newLots);
    notifyListeners();
  }

  Future<LotModel> addLot({
    required String category,
    required String subcategory,
    required double weightKg,
    required String condition,
    required double fairMin,
    required double fairMax,
    required ApiService apiService,
    String? collectorId,
    String? collectorCode,
  }) async {
    final effectiveCollectorId = collectorId ?? 'COL-TN-019284';
    final effectiveCollectorCode = collectorCode ?? 'COL-TN-019284';
    final tempId = 'TEMP-${DateTime.now().millisecondsSinceEpoch}';
    final tempLotCode = 'OFFLINE-LOT-${_pendingOutbox.length + 1}';

    final localLot = LotModel(
      id: tempId,
      lotCode: tempLotCode,
      collectorId: effectiveCollectorId,
      collectorCode: effectiveCollectorCode,
      category: category,
      subcategory: subcategory,
      estimatedWeightKg: weightKg,
      condition: condition,
      fairValueMin: fairMin,
      fairValueMax: fairMax,
      status: 'OPEN_FOR_BIDS',
      isOfflinePending: true,
    );

    // Update in-memory state immediately for responsive UI
    _inMemoryLots.insert(0, localLot);

    if (_isOfflineMode) {
      // Save to outbox queue for future sync
      final outboxItem = {
        'client_temp_id': tempId,
        'collector_id': effectiveCollectorId,
        'category': category,
        'subcategory': subcategory,
        'estimated_weight_kg': weightKg,
        'condition': condition,
        'created_timestamp': DateTime.now().toIso8601String(),
      };
      _pendingOutbox.add(outboxItem);
      await _persistOutbox();
      notifyListeners();
      return localLot;
    } else {
      // Live online API call
      try {
        final serverLot = await apiService.createLot(
          collectorId: 'COL-TN-019284',
          category: category,
          subcategory: subcategory,
          weightKg: weightKg,
          condition: condition,
        );
        // Replace temp item with server canonical item
        final idx = _inMemoryLots.indexWhere((l) => l.id == tempId);
        if (idx != -1) {
          _inMemoryLots[idx] = serverLot;
        }
        notifyListeners();
        return serverLot;
      } catch (e) {
        // Fallback to offline queue on network failure
        final outboxItem = {
          'client_temp_id': tempId,
          'collector_id': 'COL-TN-019284',
          'category': category,
          'subcategory': subcategory,
          'estimated_weight_kg': weightKg,
          'condition': condition,
          'created_timestamp': DateTime.now().toIsoformatString(),
        };
        _pendingOutbox.add(outboxItem);
        await _persistOutbox();
        notifyListeners();
        return localLot;
      }
    }
  }

  Future<int> syncPendingQueue(ApiService apiService) async {
    if (_pendingOutbox.isEmpty) return 0;

    try {
      final syncPayload = {'items': List<Map<String, dynamic>>.from(_pendingOutbox)};
      final response = await apiService.syncOfflineLots(syncPayload);

      final syncedCount = response['synced_count'] as int? ?? 0;
      _pendingOutbox.clear();
      await _persistOutbox();

      // Refresh in-memory lots from server
      final freshLots = await apiService.fetchLots();
      setLots(freshLots);

      notifyListeners();
      return syncedCount;
    } catch (e) {
      debugPrint('Sync failed: $e');
      return 0;
    }
  }

  Future<void> _persistOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = _pendingOutbox.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList(_outboxKey, serialized);
  }
}

extension DateTimeIso on DateTime {
  String toIsoformatString() => toUtc().toIso8601String();
}
