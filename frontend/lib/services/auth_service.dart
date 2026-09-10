import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  static const String _storageKey = 'ecoscrap_user_session';

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentRole => _currentUser?.role ?? '';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final Map<String, dynamic> json = jsonDecode(raw);
        _currentUser = UserModel.fromStorageJson(json);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error restoring user session: ');
    }
  }

  Future<UserModel> login({
    required ApiService apiService,
    required String identifier,
    required String password,
    String? role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiService.login(
        identifier: identifier,
        password: password,
        role: role,
      );

      final token = res['access_token'] ?? '';
      final profile = (res['profile'] as Map<String, dynamic>?) ?? {};
      final user = UserModel.fromJson(res, token, profile);

      _currentUser = user;
      await _persistSession(user);
      _isLoading = false;
      notifyListeners();
      return user;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<UserModel> quickDemoLogin({
    required ApiService apiService,
    required String role,
  }) async {
    String identifier;
    String password;

    switch (role.toUpperCase()) {
      case 'COLLECTOR':
        identifier = '9842100001';
        password = 'password123';
        break;
      case 'RECYCLER':
        identifier = '9842100010';
        password = 'password123';
        break;
      case 'ADMIN':
        identifier = 'admin@ecoscrap.in';
        password = 'admin123';
        break;
      default:
        identifier = '9842100001';
        password = 'password123';
    }

    return login(
      apiService: apiService,
      identifier: identifier,
      password: password,
      role: role.toUpperCase(),
    );
  }

  Future<UserModel> register({
    required ApiService apiService,
    required String name,
    required String phone,
    required String password,
    required String role,
    String? email,
    String language = 'ta',
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await apiService.register(
        name: name,
        phone: phone,
        password: password,
        role: role,
        email: email,
        language: language,
      );

      final token = res['access_token'] ?? '';
      final profile = (res['profile'] as Map<String, dynamic>?) ?? {};
      final user = UserModel.fromJson(res, token, profile);

      _currentUser = user;
      await _persistSession(user);
      _isLoading = false;
      notifyListeners();
      return user;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _errorMessage = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    notifyListeners();
  }

  Future<void> _persistSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(user.toJson()));
  }
}
