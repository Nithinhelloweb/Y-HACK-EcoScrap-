class UserModel {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String role; // 'COLLECTOR', 'RECYCLER', 'ADMIN'
  final String language;
  final String token;
  final Map<String, dynamic> profileData;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.role,
    this.language = 'ta',
    required this.token,
    this.profileData = const {},
  });

  bool get isCollector => role.toUpperCase() == 'COLLECTOR';
  bool get isRecycler => role.toUpperCase() == 'RECYCLER';
  bool get isAdmin => role.toUpperCase() == 'ADMIN';

  String get collectorCode => profileData['collector_code'] ?? 'COL-TN-019284';
  double get trustScore => (profileData['trust_score'] as num?)?.toDouble() ?? 92.5;
  String get registrationNo => profileData['registration_no'] ?? 'CPCB-TN-REC-2024-8812';
  String get orgName => profileData['org_name'] ?? name;
  String get officerId => profileData['officer_id'] ?? 'CPCB-TN-OFFICER-001';

  factory UserModel.fromJson(Map<String, dynamic> json, String token, Map<String, dynamic> profile) {
    final userJson = json['user'] is Map<String, dynamic> ? json['user'] : json;
    return UserModel(
      id: userJson['id'] ?? '',
      name: userJson['name'] ?? '',
      phone: userJson['phone'] ?? '',
      email: userJson['email'],
      role: (json['role'] ?? userJson['role'] ?? 'COLLECTOR').toString().toUpperCase(),
      language: userJson['language'] ?? 'ta',
      token: token,
      profileData: profile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'language': language,
      'token': token,
      'profile': profileData,
    };
  }

  factory UserModel.fromStorageJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      role: (json['role'] ?? 'COLLECTOR').toString().toUpperCase(),
      language: json['language'] ?? 'ta',
      token: json['token'] ?? '',
      profileData: (json['profile'] as Map<String, dynamic>?) ?? {},
    );
  }
}
