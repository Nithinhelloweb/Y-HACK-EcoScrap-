import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ecoscrap/screens/collector_screen.dart';
import 'package:ecoscrap/services/api_service.dart';
import 'package:ecoscrap/services/offline_store.dart';
import 'package:ecoscrap/models/lot_model.dart';

class MockApiService extends ApiService {
  @override
  Future<Map<String, dynamic>> fetchCollectorProfile(String userId) async {
    return {
      "user_id": "default",
      "role": "COLLECTOR",
      "profile": {
        "profile_type": "COLLECTOR",
        "collector_id": "c110689b-7a97-45fd-8b39-22931cdac400",
        "collector_code": "COL-TN-019285",
        "trust_score": 91.0,
        "service_area": "Peelamedu & Hopes College, Coimbatore",
        "total_collections_count": 94.0,
        "training_completed": true,
        "total_lots": 92,
        "total_earnings_inr": 6050,
        "is_verified": true,
        "name": "Selvam R.",
        "phone": "9842100002"
      }
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentHistory(String collectorId) async {
    return [
      {
        "id": "e987691d-e6cf-43cd-b3bc-6bc5c8db2cad",
        "transaction_reference": "TXN-DEMO-7F7BE3FA",
        "lot_id": null,
        "collector_id": "7f7be3fa-e1ef-4fb6-bd10-ea50ae3db131",
        "recycler_id": null,
        "amount": 6050.0,
        "currency": "INR",
        "status": "SETTLED",
        "payment_method": "UPI Direct Escrow",
        "settlement_date": "2026-09-11T04:20:26.920571",
        "created_at": "2026-09-10T22:50:26.924572"
      }
    ];
  }

  @override
  Future<List<LotModel>> fetchLots() async {
    final file = File('test/fixtures/lots.json');
    final jsonStr = file.readAsStringSync();
    final List decoded = jsonDecode(jsonStr);
    return decoded.map((item) => LotModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  @override
  Future<Map<String, dynamic>> getFairValue({
    required String category,
    required String subcategory,
    required double weightKg,
    String condition = 'mixed',
  }) async {
    return {
      'fair_value_min': 4500.0,
      'fair_value_max': 5500.0,
      'base_rate_per_kg': 500.0,
    };
  }

  @override
  Future<Map<String, dynamic>> fetchSafetyProtocols() async {
    return {};
  }
}

void main() {
  test('Parsing all 92 backend lots from JSON into LotModel', () {
    final file = File('test/fixtures/lots.json');
    final jsonStr = file.readAsStringSync();
    final List decoded = jsonDecode(jsonStr);
    final lots = decoded.map((item) => LotModel.fromJson(item as Map<String, dynamic>)).toList();
    expect(lots.length, 92);
  });

  testWidgets('CollectorScreen renders with all 92 lots and profile data across all subtabs', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final offlineStore = OfflineStore();
    await offlineStore.init();
    final apiService = MockApiService();

    final lots = await apiService.fetchLots();
    await offlineStore.setLots(lots);

    for (int tab = 0; tab < 4; tab++) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CollectorScreen(
              apiService: apiService,
              offlineStore: offlineStore,
              currentLang: 'en',
              onLangChanged: (_) {},
              initialTab: tab,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
