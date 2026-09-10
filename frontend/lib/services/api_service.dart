import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lot_model.dart';

class ApiService {
  // Use localhost for web and desktop, 10.0.2.2 for Android emulator
  final String baseUrl;

  ApiService({this.baseUrl = 'http://127.0.0.1:8000/api'});

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
}
