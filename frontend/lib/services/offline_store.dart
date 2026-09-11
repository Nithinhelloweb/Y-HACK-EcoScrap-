import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lot_model.dart';
import 'api_service.dart';

class OfflineStore extends ChangeNotifier {
  static const String _outboxKey = 'ecoscrap_outbox';
  static const String _cachedLotsKey = 'ecoscrap_cached_lots';
  
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  final List<LotModel> _inMemoryLots = [];
  List<LotModel> get lots => List.unmodifiable(_inMemoryLots);

  final List<Map<String, dynamic>> _pendingOutbox = [];
  List<Map<String, dynamic>> get pendingOutbox => List.unmodifiable(_pendingOutbox);

  int get pendingCount => _pendingOutbox.length;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  String? _lastSyncStatus;
  String? get lastSyncStatus => _lastSyncStatus;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Load pending outbox
      final rawOutbox = prefs.getStringList(_outboxKey) ?? [];
      _pendingOutbox.clear();
      for (final item in rawOutbox) {
        try {
          _pendingOutbox.add(jsonDecode(item) as Map<String, dynamic>);
        } catch (_) {}
      }

      // 2. Load cached lots from persistent storage
      final rawLots = prefs.getStringList(_cachedLotsKey) ?? [];
      _inMemoryLots.clear();
      for (final item in rawLots) {
        try {
          final map = jsonDecode(item) as Map<String, dynamic>;
          _inMemoryLots.add(LotModel.fromJson(map));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('OfflineStore init error: $e');
    }
    notifyListeners();
  }

  void toggleOfflineMode() {
    _isOfflineMode = !_isOfflineMode;
    notifyListeners();
  }

  void setOfflineMode(bool value) {
    if (_isOfflineMode != value) {
      _isOfflineMode = value;
      notifyListeners();
    }
  }

  Future<void> setLots(List<LotModel> newLots) async {
    _inMemoryLots.clear();
    _inMemoryLots.addAll(newLots);
    await _persistCachedLots();
    notifyListeners();
  }

  Future<void> clearAllLots() async {
    _inMemoryLots.clear();
    _pendingOutbox.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cachedLotsKey);
      await prefs.remove(_outboxKey);
    } catch (e) {
      debugPrint('OfflineStore clearAllLots error: $e');
    }
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

    // Update in-memory state immediately for ultra-responsive UI
    _inMemoryLots.insert(0, localLot);
    await _persistCachedLots();

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
          collectorId: effectiveCollectorId,
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
        await _persistCachedLots();
        notifyListeners();
        return serverLot;
      } catch (e) {
        // Fallback to offline queue on network failure
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
      }
    }
  }

  Future<int> syncPendingQueue(ApiService apiService) async {
    if (_pendingOutbox.isEmpty) {
      _lastSyncTime = DateTime.now();
      _lastSyncStatus = 'All lots already synced';
      notifyListeners();
      return 0;
    }

    _isSyncing = true;
    notifyListeners();

    try {
      final syncPayload = {'items': List<Map<String, dynamic>>.from(_pendingOutbox)};
      final response = await apiService.syncOfflineLots(syncPayload);

      final syncedCount = response['synced_count'] as int? ?? 0;
      _pendingOutbox.clear();
      await _persistOutbox();

      // Refresh in-memory lots from server
      final freshLots = await apiService.fetchLots();
      _inMemoryLots.clear();
      _inMemoryLots.addAll(freshLots);
      await _persistCachedLots();

      _lastSyncTime = DateTime.now();
      _lastSyncStatus = 'Successfully synced $syncedCount offline lots';
      _isOfflineMode = false;
      return syncedCount;
    } catch (e) {
      debugPrint('Sync failed: $e');
      _lastSyncStatus = 'Sync error: $e';
      return 0;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _persistOutbox() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = _pendingOutbox.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList(_outboxKey, serialized);
  }

  Future<void> _persistCachedLots() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = _inMemoryLots.map((item) => jsonEncode(item.toJson())).toList();
      await prefs.setStringList(_cachedLotsKey, serialized);
    } catch (e) {
      debugPrint('Failed to persist cached lots: $e');
    }
  }
}
