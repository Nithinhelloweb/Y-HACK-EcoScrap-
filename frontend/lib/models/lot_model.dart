class PriceFactor {
  final String name;
  final double adjustmentInr;
  final String description;

  PriceFactor({
    required this.name,
    required this.adjustmentInr,
    required this.description,
  });

  factory PriceFactor.fromJson(Map<String, dynamic> json) {
    return PriceFactor(
      name: json['name'] ?? '',
      adjustmentInr: (json['adjustment_inr'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
    );
  }
}

class AIClassifyResult {
  final String category;
  final String subcategory;
  final String itemName;
  final String grade;
  final double confidence;
  final List<String> safetyFlags;
  final String safetyGuidance;
  final double estimatedBaseRatePerKg;
  final String recommendedAction;
  final Map<String, dynamic>? visualFeatures;
  final Map<String, dynamic>? compositionBreakdown;
  final Map<String, dynamic>? fairValueEstimate;
  final bool imageAnalyzed;
  final List<dynamic>? detectedComponents;
  final Map<String, dynamic>? componentAnalysis;
  final String? detectedText;
  final List<String> extractedBrands;
  final List<String> extractedModels;
  final List<String> hazardKeywords;
  final double ocrConfidence;

  AIClassifyResult({
    required this.category,
    required this.subcategory,
    required this.itemName,
    required this.grade,
    required this.confidence,
    required this.safetyFlags,
    required this.safetyGuidance,
    required this.estimatedBaseRatePerKg,
    required this.recommendedAction,
    this.visualFeatures,
    this.compositionBreakdown,
    this.fairValueEstimate,
    this.imageAnalyzed = false,
    this.detectedComponents,
    this.componentAnalysis,
    this.detectedText,
    this.extractedBrands = const [],
    this.extractedModels = const [],
    this.hazardKeywords = const [],
    this.ocrConfidence = 0.0,
  });

  factory AIClassifyResult.fromJson(Map<String, dynamic> json) {
    return AIClassifyResult(
      category: json['category'] ?? 'PCB',
      subcategory: json['subcategory'] ?? 'IT_HIGH_GRADE_PCB',
      itemName: json['item_name'] ?? 'E-Waste Item',
      grade: json['grade'] ?? 'Standard',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      safetyFlags: List<String>.from(json['safety_flags'] ?? []),
      safetyGuidance: json['safety_guidance'] ?? 'Handle with standard caution.',
      estimatedBaseRatePerKg: (json['estimated_base_rate_per_kg'] as num?)?.toDouble() ?? 250.0,
      recommendedAction: json['recommended_action'] ?? 'Create digital lot',
      visualFeatures: json['visual_features'] as Map<String, dynamic>?,
      compositionBreakdown: json['composition_breakdown'] as Map<String, dynamic>?,
      fairValueEstimate: json['fair_value_estimate'] as Map<String, dynamic>?,
      imageAnalyzed: json['image_analyzed'] == true,
      detectedComponents: json['detected_components'] as List<dynamic>?,
      componentAnalysis: json['component_analysis'] as Map<String, dynamic>?,
      detectedText: json['detected_text'],
      extractedBrands: List<String>.from(json['extracted_brands'] ?? []),
      extractedModels: List<String>.from(json['extracted_models'] ?? []),
      hazardKeywords: List<String>.from(json['hazard_keywords'] ?? []),
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BidModel {
  final String id;
  final String recyclerId;
  final String recyclerName;
  final double offerPrice;
  final double logisticsDeduction;
  final double netCollectorPayable;
  final double matchScore;
  final String status;
  final bool isAnomaly;
  final String? anomalyReason;

  BidModel({
    required this.id,
    required this.recyclerId,
    required this.recyclerName,
    required this.offerPrice,
    required this.logisticsDeduction,
    required this.netCollectorPayable,
    required this.matchScore,
    required this.status,
    required this.isAnomaly,
    this.anomalyReason,
  });

  factory BidModel.fromJson(Map<String, dynamic> json) {
    return BidModel(
      id: json['id'] ?? '',
      recyclerId: json['recycler_id'] ?? '',
      recyclerName: json['recycler_name'] ?? 'Authorized Recycler',
      offerPrice: (json['offer_price'] as num?)?.toDouble() ?? 0.0,
      logisticsDeduction: (json['logistics_deduction'] as num?)?.toDouble() ?? 0.0,
      netCollectorPayable: (json['net_collector_payable'] as num?)?.toDouble() ?? 0.0,
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 80.0,
      status: json['status'] ?? 'SUBMITTED',
      isAnomaly: json['is_anomaly'] ?? false,
      anomalyReason: json['anomaly_reason'],
    );
  }
}

class LotModel {
  final String id;
  final String lotCode;
  final String collectorId;
  final String collectorCode;
  final String category;
  final String subcategory;
  final double estimatedWeightKg;
  final double? verifiedWeightKg;
  final String condition;
  final double fairValueMin;
  final double fairValueMax;
  final String status;
  final String? qrCodeUrl;
  final List<BidModel> bids;
  final bool isOfflinePending;

  LotModel({
    required this.id,
    required this.lotCode,
    required this.collectorId,
    required this.collectorCode,
    required this.category,
    required this.subcategory,
    required this.estimatedWeightKg,
    this.verifiedWeightKg,
    required this.condition,
    required this.fairValueMin,
    required this.fairValueMax,
    required this.status,
    this.qrCodeUrl,
    this.bids = const [],
    this.isOfflinePending = false,
  });

  factory LotModel.fromJson(Map<String, dynamic> json) {
    var rawBids = json['bids'] as List? ?? [];
    return LotModel(
      id: json['id'] ?? '',
      lotCode: json['lot_code'] ?? '',
      collectorId: json['collector_id'] ?? '',
      collectorCode: json['collector_code'] ?? 'COL-TN-019284',
      category: json['category'] ?? '',
      subcategory: json['subcategory'] ?? '',
      estimatedWeightKg: (json['estimated_weight_kg'] as num?)?.toDouble() ?? 0.0,
      verifiedWeightKg: (json['verified_weight_kg'] as num?)?.toDouble(),
      condition: json['condition'] ?? 'mixed',
      fairValueMin: (json['fair_value_min'] as num?)?.toDouble() ?? 0.0,
      fairValueMax: (json['fair_value_max'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'OPEN_FOR_BIDS',
      qrCodeUrl: json['qr_code_url'],
      bids: rawBids.map((b) => BidModel.fromJson(b)).toList(),
      isOfflinePending: json['is_offline_pending'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lot_code': lotCode,
      'collector_id': collectorId,
      'collector_code': collectorCode,
      'category': category,
      'subcategory': subcategory,
      'estimated_weight_kg': estimatedWeightKg,
      'verified_weight_kg': verifiedWeightKg,
      'condition': condition,
      'fair_value_min': fairValueMin,
      'fair_value_max': fairValueMax,
      'status': status,
      'qr_code_url': qrCodeUrl,
      'is_offline_pending': isOfflinePending,
    };
  }
}
