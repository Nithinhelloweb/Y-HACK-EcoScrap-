import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecoscrap/services/offline_store.dart';
import 'package:ecoscrap/services/api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineStore In-Memory & Offline Outbox Tests', () {
    late OfflineStore store;
    late ApiService mockApi;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = OfflineStore();
      await store.init();
      mockApi = ApiService();
    });

    test('Initial state has zero pending outbox items and offline mode is false', () {
      expect(store.isOfflineMode, isFalse);
      expect(store.pendingCount, equals(0));
      expect(store.lots, isEmpty);
    });

    test('Toggling offline mode updates isOfflineMode state', () {
      store.toggleOfflineMode();
      expect(store.isOfflineMode, isTrue);

      store.toggleOfflineMode();
      expect(store.isOfflineMode, isFalse);
    });

    test('Adding lot while offline queues item to outbox and updates in-memory lots', () async {
      store.toggleOfflineMode(); // Turn offline ON
      expect(store.isOfflineMode, isTrue);

      final lot = await store.addLot(
        category: 'PCB',
        subcategory: 'IT_HIGH_GRADE_PCB',
        weightKg: 8.4,
        condition: 'mixed',
        fairMin: 4700.0,
        fairMax: 5200.0,
        apiService: mockApi,
      );
      expect(lot.category, equals('PCB'));

      // Verify in-memory state has updated immediately
      expect(store.lots.length, equals(1));
      expect(store.lots.first.lotCode, startsWith('OFFLINE-LOT-'));
      expect(store.lots.first.isOfflinePending, isTrue);

      // Verify pending outbox queue has 1 record
      expect(store.pendingCount, equals(1));
      expect(store.pendingOutbox.first['category'], equals('PCB'));
      expect(store.pendingOutbox.first['estimated_weight_kg'], equals(8.4));
    });
  });
}
