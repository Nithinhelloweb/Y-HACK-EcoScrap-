class CollectionItemModel {
  final String? id;
  final String name;
  final String normalizedType;
  final double quantity;
  final String unit;
  final double? estimatedWeightKg;

  CollectionItemModel({
    this.id,
    required this.name,
    required this.normalizedType,
    required this.quantity,
    this.unit = 'units',
    this.estimatedWeightKg,
  });

  factory CollectionItemModel.fromJson(Map<String, dynamic> json) {
    return CollectionItemModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      normalizedType: json['normalized_type'] as String? ?? 'UNKNOWN',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      unit: json['unit'] as String? ?? 'units',
      estimatedWeightKg: (json['estimated_weight_kg'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'normalized_type': normalizedType,
      'quantity': quantity,
      'unit': unit,
      if (estimatedWeightKg != null) 'estimated_weight_kg': estimatedWeightKg,
    };
  }
}

class CollectionModel {
  final String id;
  final String collectionCode;
  final String collectorId;
  final String sourceType;
  final String status;
  final double totalItemsCount;
  final String? notes;
  final List<CollectionItemModel> items;
  final DateTime createdAt;

  CollectionModel({
    required this.id,
    required this.collectionCode,
    required this.collectorId,
    this.sourceType = 'household',
    this.status = 'DRAFT',
    this.totalItemsCount = 0.0,
    this.notes,
    this.items = const [],
    required this.createdAt,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
    return CollectionModel(
      id: json['id'] as String? ?? '',
      collectionCode: json['collection_code'] as String? ?? '',
      collectorId: json['collector_id'] as String? ?? '',
      sourceType: json['source_type'] as String? ?? 'household',
      status: json['status'] as String? ?? 'DRAFT',
      totalItemsCount: (json['total_items_count'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      items: (json['items'] as List<dynamic>? ?? [])
          .map((item) => CollectionItemModel.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection_code': collectionCode,
      'collector_id': collectorId,
      'source_type': sourceType,
      'status': status,
      'total_items_count': totalItemsCount,
      if (notes != null) 'notes': notes,
      'items': items.map((i) => i.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
