import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'api_client.dart';

class AuthService extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _token;
  String? _userName;
  String? _userSurname;
  String? _role;
  String? _roleId;
  String? _userId;
  Map<String, dynamic>? _userData;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get token => _token;
  String? get userName => _userName;
  String? get userSurname => _userSurname;
  String? get role => _role;
  String? get roleId => _roleId;
  String? get userId => _userId;
  Map<String, dynamic>? get userData => _userData;

  AuthService() {
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    _isLoading = true;
    notifyListeners();

    _token = await _storage.read(key: 'token');
    _userName = await _storage.read(key: 'userName');
    _userSurname = await _storage.read(key: 'userSurname');
    _role = await _storage.read(key: 'role');
    _roleId = await _storage.read(key: 'roleId');
    _userId = await _storage.read(key: 'userId');
    final userDataStr = await _storage.read(key: 'userData');
    if (userDataStr != null) {
      _userData = jsonDecode(userDataStr);
    }

    _isLoggedIn = _token != null;
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await _apiClient.post('/login', {
        'username': username,
        'password': password,
      });

      if (response['success'] == true && response['token'] != null) {
        _token = response['token'];
        final users = response['users'] as Map<String, dynamic>;
        _userName = users['name'] ?? '';
        _userSurname = users['surname'] ?? '';
        _userId = users['user_id']?.toString();

        // Get role info
        final roles = users['roles'] as List<dynamic>?;
        if (roles != null && roles.isNotEmpty) {
          final firstRole = roles[0] as Map<String, dynamic>;
          _role = firstRole['name'];
          _roleId = firstRole['id']?.toString();
        }

        // Get user_data (student details)
        if (users['user_data'] != null) {
          _userData = users['user_data'] is Map<String, dynamic>
              ? users['user_data']
              : null;
        }

        // Save to secure storage
        await _apiClient.saveToken(_token!);
        await _storage.write(key: 'token', value: _token);
        await _storage.write(key: 'userName', value: _userName);
        await _storage.write(key: 'userSurname', value: _userSurname);
        await _storage.write(key: 'role', value: _role);
        await _storage.write(key: 'roleId', value: _roleId);
        await _storage.write(key: 'userId', value: _userId);
        if (_userData != null) {
          await _storage.write(
              key: 'userData', value: jsonEncode(_userData));
        }

        _isLoggedIn = true;
        notifyListeners();
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Login failed'
        };
      }
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      return {'success': false, 'message': 'Network error. Please try again.'};
    }
  }

  Future<void> logout() async {
    await _storage.deleteAll();
    await _apiClient.clearToken();
    _isLoggedIn = false;
    _token = null;
    _userName = null;
    _userSurname = null;
    _role = null;
    _roleId = null;
    _userId = null;
    _userData = null;
    notifyListeners();
  }
}
