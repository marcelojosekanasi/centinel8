import 'dart:io';
import 'package:flutter/material.dart';
import 'package:centinel8/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => _user != null && _user!["rol_id"] == 2;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> checkAuth() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final token = await _apiService.getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final profileData = await _apiService.getProfile();
      _user = profileData;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      await _apiService.deleteToken();
      _user = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final data = await _apiService.login(email, password);
      final token = data["access_token"];
      _user = data["usuario"];
      await _apiService.saveToken(token);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("HttpException: ", "");
      _isLoading = false;
      _user = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String nombre, String apellido, String ci, String celular, String correo, String contrasena) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _apiService.register(nombre, apellido, ci, celular, correo, contrasena);
      return await login(correo, contrasena);
    } catch (e) {
      _errorMessage = e.toString().replaceAll("HttpException: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.logout();
    } catch (_) {
      await _apiService.deleteToken();
    }
    _user = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> updateProfile(String nombre, String apellido, String celular, String correo) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final updated = await _apiService.updateProfile({
        "nombre": nombre,
        "apellido": apellido,
        "celular": celular,
        "correo": correo,
      });
      _user = updated;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("HttpException: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> changePassword(String currentPassword, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _apiService.changePassword(currentPassword, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("HttpException: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> recoverPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _apiService.recoverPassword(email);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("HttpException: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetPassword(String token, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _apiService.resetPassword(token, newPassword);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll("HttpException: ", "");
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
