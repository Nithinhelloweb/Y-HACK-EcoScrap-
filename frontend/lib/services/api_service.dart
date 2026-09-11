import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lot_model.dart';

class ApiService {
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://ecoscrap.srishakthicgpa.in/api',
  );
  static const String prefKeyBaseUrl = 'ecoscrap_api_base_url';

  String _baseUrl;
  String get baseUrl => _baseUrl;

  ApiService({String? baseUrl})
      : _baseUrl = _normalizeUrl(baseUrl ?? _defaultBaseUrl);

  static String _normalizeUrl(String url) {
    var u = url.trim();
    if (u.isEmpty) {
      return _defaultBaseUrl;
    }
    if (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (!u.endsWith('/api')) {
      u = '$u/api';
    }
    return u;
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKeyBaseUrl);
      if (saved != null && saved.trim().isNotEmpty) {
        _baseUrl = _normalizeUrl(saved);
        return;
      }

      // Load bundled assets/config.json if available
      try {
        final configStr = await rootBundle.loadString('assets/config.json');
        final Map<String, dynamic> config = jsonDecode(configStr);
        if (config['api_url'] != null && config['api_url'].toString().trim().isNotEmpty) {
          _baseUrl = _normalizeUrl(config['api_url'].toString());
          return;
        }
      } catch (_) {}
    } catch (_) {}
  }

  Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = _normalizeUrl(newUrl);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKeyBaseUrl, _baseUrl);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> testConnection([String? candidateUrl]) async {
    final target = candidateUrl != null && candidateUrl.trim().isNotEmpty
        ? _normalizeUrl(candidateUrl)
        : _baseUrl;
    final stopwatch = Stopwatch()..start();
    try {
      final rootUrl = target.endsWith('/api')
          ? target.substring(0, target.length - 4)
          : target;
      final uri = Uri.parse('$rootUrl/api/health');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'latency_ms': stopwatch.elapsedMilliseconds,
          'target_url': target,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'latency_ms': stopwatch.elapsedMilliseconds,
          'target_url': target,
          'error': 'Server returned HTTP ${response.statusCode}',
        };
      }
    } catch (e) {
      stopwatch.stop();
      return {
        'success': false,
        'latency_ms': stopwatch.elapsedMilliseconds,
        'target_url': target,
        'error': e.toString(),
      };
    }
  }


  Future<AIClassifyResult> classifyMaterial(String queryText) async {
    final uri = Uri.parse('$baseUrl/ai/classify');
    final response = await http.post(uri, body: {'query_text': queryText});

    if (response.statusCode == 200) {
      return AIClassifyResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Classification failed: ${response.body}');
    }
  }

  Future<AIClassifyResult> classifyImageBytes({
    required List<int> bytes,
    required String filename,
    String hintText = '',
  }) async {
    final uri = Uri.parse('$baseUrl/ai/classify-image');
    final request = http.MultipartRequest('POST', uri);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
    ));
    if (hintText.isNotEmpty) {
      request.fields['hint_text'] = hintText;
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return AIClassifyResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Image classification failed: ${response.body}');
    }
  }

  Future<AIClassifyResult> classifyImageBase64({
    required String base64Data,
    String hintText = '',
  }) async {
    final uri = Uri.parse('$baseUrl/ai/classify-image');
    final response = await http.post(uri, body: {
      'image_base64': base64Data,
      'hint_text': hintText,
    });

    if (response.statusCode == 200) {
      return AIClassifyResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Image classification failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> extractOCR({
    required String base64Data,
  }) async {
    final uri = Uri.parse('$baseUrl/ai/ocr');
    final response = await http.post(uri, body: {
      'image_base64': base64Data,
    });
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('OCR text extraction failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> submitDetectionFeedback({
    String? imageBase64,
    String? originalItemName,
    String? originalCategory,
    String? originalSubcategory,
    required String correctedItemName,
    required String correctedCategory,
    required String correctedSubcategory,
    double? correctedWeightKg,
    double? correctedQuantity,
    String? correctedCondition,
    List<double>? boundingBox,
    String? collectorId,
  }) async {
    final uri = Uri.parse('$baseUrl/ai/edit-feedback');
    final payload = <String, dynamic>{
      'corrected_item_name': correctedItemName,
      'corrected_category': correctedCategory,
      'corrected_subcategory': correctedSubcategory,
    };
    if (imageBase64 != null) payload['image_base64'] = imageBase64;
    if (originalItemName != null) payload['original_item_name'] = originalItemName;
    if (originalCategory != null) payload['original_category'] = originalCategory;
    if (originalSubcategory != null) payload['original_subcategory'] = originalSubcategory;
    if (correctedWeightKg != null) payload['corrected_weight_kg'] = correctedWeightKg;
    if (correctedQuantity != null) payload['corrected_quantity'] = correctedQuantity;
    if (correctedCondition != null) payload['corrected_condition'] = correctedCondition;
    if (boundingBox != null) payload['bounding_box'] = boundingBox;
    if (collectorId != null) payload['collector_id'] = collectorId;

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Feedback submission failed: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getSelfTrainingStatus() async {
    final uri = Uri.parse('$baseUrl/ai/self-train/status');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch self-training status: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> triggerSelfTraining({int epochs = 5}) async {
    final uri = Uri.parse('$baseUrl/ai/self-train');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'epochs': epochs}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to trigger self-training: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createCollectionDraft({
    required String collectorId,
    required List<Map<String, dynamic>> items,
    String sourceType = 'household',
  }) async {
    final uri = Uri.parse('$baseUrl/collections');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'collector_id': collectorId,
        'source_type': sourceType,
        'items': items,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create collection draft: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getFairValue({
    required String category,
    required String subcategory,
    required double weightKg,
    String condition = 'mixed',
  }) async {
    final uri = Uri.parse('$baseUrl/ai/fair-value');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'category': category,
        'subcategory': subcategory,
        'weight_kg': weightKg,
        'condition': condition,
        'distance_km': 15.0,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Fair value estimation failed: ${response.body}');
    }
  }

  Future<List<LotModel>> fetchLots() async {
    final uri = Uri.parse('$baseUrl/lots');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((json) => LotModel.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch lots: ${response.body}');
    }
  }

  Future<LotModel> createLot({
    required String collectorId,
    required String category,
    required String subcategory,
    required double weightKg,
    required String condition,
  }) async {
    final uri = Uri.parse('$baseUrl/lots');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'collector_id': collectorId,
        'category': category,
        'subcategory': subcategory,
        'estimated_weight_kg': weightKg,
        'condition': condition,
      }),
    );

    if (response.statusCode == 200) {
      return LotModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create lot: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> syncOfflineLots(Map<String, dynamic> payload) async {
    final uri = Uri.parse('$baseUrl/lots/sync');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to sync offline lots: ${response.body}');
    }
  }

  Future<BidModel> submitBid({
    required String lotId,
    required String recyclerId,
    required double offerPrice,
    double deduction = 100.0,
  }) async {
    final uri = Uri.parse('$baseUrl/bids');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'lot_id': lotId,
        'recycler_id': recyclerId,
        'offer_price': offerPrice,
        'logistics_deduction': deduction,
      }),
    );

    if (response.statusCode == 200) {
      return BidModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to submit bid: ${response.body}');
    }
  }

  Future<BidModel> acceptBid(String bidId) async {
    final uri = Uri.parse('$baseUrl/bids/$bidId/accept');
    final response = await http.post(uri);

    if (response.statusCode == 200) {
      return BidModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to accept bid: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> startHandover(String lotId) async {
    final uri = Uri.parse('$baseUrl/handover/$lotId/start');
    final response = await http.post(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to start handover: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> verifyHandover({
    required String lotId,
    required String otpCode,
    required double scaleWeightKg,
  }) async {
    final uri = Uri.parse('$baseUrl/handover/verify');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'lot_id': lotId,
        'otp_code': otpCode,
        'scale_weight_kg': scaleWeightKg,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to verify handover: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> completeProcessing(String lotId) async {
    final uri = Uri.parse('$baseUrl/handover/$lotId/process');
    final response = await http.post(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to complete processing: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchPassport(String lotCode) async {
    final uri = Uri.parse('$baseUrl/passport/$lotCode');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch passport: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchAdminMetrics() async {
    final uri = Uri.parse('$baseUrl/admin/metrics');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch admin metrics: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> parseVoicePrompt(String text, {String? lang}) async {
    final uri = Uri.parse('$baseUrl/voice/parse');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'language_hint': lang,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to parse voice prompt: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> assessSafety({
    required String category,
    required String subcategory,
    String condition = 'normal',
  }) async {
    final uri = Uri.parse('$baseUrl/safety/assess');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'category': category,
        'subcategory': subcategory,
        'condition': condition,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to assess safety: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> fetchSafetyProtocols() async {
    final uri = Uri.parse('$baseUrl/safety/protocols');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch safety protocols: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
    String? role,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login');
    final payload = <String, dynamic>{
      'identifier': identifier.trim(),
      'password': password,
    };
    if (role != null) {
      payload['role'] = role;
    }
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Login failed (${response.statusCode})');
    }
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required String role,
    String? email,
    String language = 'ta',
  }) async {
    final uri = Uri.parse('$baseUrl/auth/register');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'phone': phone,
        'email': email,
        'password': password,
        'role': role,
        'language': language,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Registration failed (${response.statusCode})');
    }
  }

  Future<List<Map<String, dynamic>>> fetchDemoUsers() async {
    final uri = Uri.parse('$baseUrl/auth/demo-users');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.cast<Map<String, dynamic>>();
    } else {
      return [
        {
          'role': 'COLLECTOR',
          'name': 'Murugan K.',
          'identifier': '9842100001',
          'password': 'password123',
          'description': 'Field Scrap Collector (Trust Score 94.5)',
          'badge': 'COL-TN-019284',
        },
        {
          'role': 'RECYCLER',
          'name': 'GreenTech E-Recovery',
          'identifier': '9842100010',
          'password': 'password123',
          'description': 'CPCB-Authorized Dismantler (Reliability 96.0)',
          'badge': 'CPCB-TN-REC-2024-8812',
        },
        {
          'role': 'ADMIN',
          'name': 'CPCB Inspector Arumugam S.',
          'identifier': 'admin@ecoscrap.in',
          'password': 'admin123',
          'description': 'State Regulatory Oversight & Anomaly Auditor',
          'badge': 'CPCB-TN-OFFICER-001',
        },
      ];
    }
  }

  // ─── Collector Profile & Earnings ───────────────────────────────────────────

  Future<Map<String, dynamic>> fetchCollectorProfile(String userId) async {
    final uri = Uri.parse('$baseUrl/auth/profile/$userId');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch profile: ${response.body}');
  }

  Future<List<Map<String, dynamic>>> fetchPaymentHistory(String collectorId) async {
    final uri = Uri.parse('$baseUrl/payments/collector/$collectorId');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch payment history: ${response.body}');
  }

  // ─── Recycler Bid History & Performance ─────────────────────────────────────

  Future<Map<String, dynamic>> fetchRecyclerBids(String recyclerId) async {
    final uri = Uri.parse('$baseUrl/recycler/$recyclerId/bids');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch recycler bids: ${response.body}');
  }

  Future<Map<String, dynamic>> fetchRecyclerStats(String recyclerId) async {
    final uri = Uri.parse('$baseUrl/recycler/$recyclerId/stats');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch recycler stats: ${response.body}');
  }

  // ─── Lot Lifecycle Transitions ──────────────────────────────────────────────

  Future<Map<String, dynamic>> markLotProcessing(String lotId) async {
    final uri = Uri.parse('$baseUrl/lots/$lotId/process');
    final response = await http.post(uri);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to mark lot as processing: ${response.body}');
  }

  Future<Map<String, dynamic>> markLotRecovered(String lotId) async {
    final uri = Uri.parse('$baseUrl/lots/$lotId/recover');
    final response = await http.post(uri);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to mark lot as recovered: ${response.body}');
  }

  Future<Map<String, dynamic>> closeLot(String lotId) async {
    final uri = Uri.parse('$baseUrl/lots/$lotId/close');
    final response = await http.post(uri);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to close lot: ${response.body}');
  }

  // ─── Admin Analytics ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchAdminCollectors() async {
    final uri = Uri.parse('$baseUrl/admin/collectors');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch collectors: ${response.body}');
  }

  Future<List<Map<String, dynamic>>> fetchAdminRecyclers() async {
    final uri = Uri.parse('$baseUrl/admin/recyclers');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch recyclers: ${response.body}');
  }

  Future<Map<String, dynamic>> fetchMarketTrends() async {
    final uri = Uri.parse('$baseUrl/admin/market-trends');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch market trends: ${response.body}');
  }

  Future<Map<String, dynamic>> fetchEnvironmentalSummary() async {
    final uri = Uri.parse('$baseUrl/admin/environmental-impact');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch environmental impact: ${response.body}');
  }

  Future<Map<String, dynamic>> fetchFraudAlerts({String? severity}) async {
    final uri = Uri.parse(
        '$baseUrl/admin/fraud-alerts${severity != null ? '?severity=$severity' : ''}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch fraud alerts: ${response.body}');
  }

  Future<Map<String, dynamic>> verifyUser(
      String userId, bool verified) async {
    final uri = Uri.parse('$baseUrl/admin/verify-user');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'verified': verified}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to verify user: ${response.body}');
  }

  // ----------------- Disputes API -----------------
  Future<Map<String, dynamic>> createDispute({
    required String lotId,
    required String raisedById,
    String? raisedByName,
    String raisedByRole = 'COLLECTOR',
    String disputeType = 'WEIGHT_MISMATCH',
    required String description,
    String? evidenceNotes,
  }) async {
    final uri = Uri.parse('$baseUrl/disputes');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'lot_id': lotId,
        'raised_by_id': raisedById,
        'raised_by_name': raisedByName,
        'raised_by_role': raisedByRole,
        'dispute_type': disputeType,
        'description': description,
        'evidence_notes': evidenceNotes,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to create dispute: ${response.body}');
  }

  Future<List<Map<String, dynamic>>> fetchDisputes({String? status, String? lotId}) async {
    final qParams = <String>[];
    if (status != null) qParams.add('status=$status');
    if (lotId != null) qParams.add('lot_id=$lotId');
    final queryStr = qParams.isNotEmpty ? '?${qParams.join('&')}' : '';
    final uri = Uri.parse('$baseUrl/disputes$queryStr');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to fetch disputes: ${response.body}');
  }

  Future<Map<String, dynamic>> resolveDispute({
    required String disputeId,
    required String resolutionDecision,
    String? resolutionNotes,
    double settlementAdjustmentInr = 0.0,
  }) async {
    final uri = Uri.parse('$baseUrl/disputes/$disputeId/resolve');
    final response = await http.patch(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'resolution_decision': resolutionDecision,
        'resolution_notes': resolutionNotes,
        'settlement_adjustment_inr': settlementAdjustmentInr,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to resolve dispute: ${response.body}');
  }

  // ----------------- Recycler Recovery Recording -----------------
  Future<Map<String, dynamic>> recordLotRecovery({
    required String lotId,
    required Map<String, double> recoveredFractions,
    String? recyclerId,
    String? notes,
  }) async {
    final uri = Uri.parse('$baseUrl/lots/$lotId/recovery');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'lot_id': lotId,
        'recycler_id': recyclerId,
        'recovered_fractions': recoveredFractions,
        'notes': notes,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to record recovery: ${response.body}');
  }

  // ----------------- Geographic Intelligence -----------------
  Future<Map<String, dynamic>> fetchGeographicIntelligence() async {
    final uri = Uri.parse('$baseUrl/admin/geographic-intelligence');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch geographic intelligence: ${response.body}');
  }

  // ----------------- Ecosystem Integrations -----------------
  Future<Map<String, dynamic>> fetchIntegrations() async {
    final uri = Uri.parse('$baseUrl/admin/integrations');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch integrations: ${response.body}');
  }

  // ----------------- Audit Logs -----------------
  Future<Map<String, dynamic>> fetchAuditLogs({int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/admin/audit-logs?limit=$limit');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to fetch audit logs: ${response.body}');
  }

  // ----------------- Duplicate Lot Detection -----------------
  Future<Map<String, dynamic>> checkDuplicateLot({
    required String category,
    required String subcategory,
    required double estimatedWeightKg,
    String? collectorId,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/check-duplicate-lot');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'category': category,
        'subcategory': subcategory,
        'estimated_weight_kg': estimatedWeightKg,
        'collector_id': collectorId,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to check duplicate lot: ${response.body}');
  }
}
