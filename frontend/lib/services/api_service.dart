import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // En emulador de Android 10.0.2.2 apunta al localhost de la máquina host.
  // Para iOS o web se puede configurar a localhost o a una IP de red.
  static const String defaultBaseUrl =
    "http://192.168.0.7:8000/api/v1";
  final String baseUrl;
  final _storage = const FlutterSecureStorage();

  ApiService({this.baseUrl = defaultBaseUrl});

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: "jwt_token", value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: "jwt_token");
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: "jwt_token");
  }

  // --- AUTENTICACIÓN ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"correo": email, "contrasena": password}),
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> register(
    String nombre,
    String apellido,
    String ci,
    String celular,
    String correo,
    String contrasena,
  ) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nombre": nombre,
        "apellido": apellido,
        "ci": ci,
        "celular": celular,
        "correo": correo,
        "contrasena": contrasena,
        "rol_id": 1 // Vecino
      }),
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> logout() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse("$baseUrl/auth/logout"),
      headers: headers,
    );
    await deleteToken();
    return _processResponse(response);
  }

  // --- PERFIL ---

  Future<Map<String, dynamic>> getProfile() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse("$baseUrl/users/me"), headers: headers);
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse("$baseUrl/users/me"),
      headers: headers,
      body: jsonEncode(data),
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse("$baseUrl/users/change-password"),
      headers: headers,
      body: jsonEncode({
        "contrasena_actual": currentPassword,
        "nueva_contrasena": newPassword
      }),
    );
    return _processResponse(response);
  }

  // --- INCIDENTES ---

  Future<List<dynamic>> getIncidents({
    bool personal = false,
    int? categoryId,
    String? status,
  }) async {
    final headers = await _getHeaders();
    String query = "?personal=$personal";
    if (categoryId != null) query += "&categoria_id=$categoryId";
    if (status != null) query += "&estado=$status";

    final response = await http.get(
      Uri.parse("$baseUrl/incidents/$query"),
      headers: headers,
    );
    final processed = _processResponse(response);
    return processed is List ? processed : [];
  }

  Future<Map<String, dynamic>> createIncident({
    required int categoryId,
    required String descripcion,
    required double latitud,
    required double longitud,
    required String direccion,
    File? imageFile,
  }) async {
    final token = await getToken();
    final uri = Uri.parse("$baseUrl/incidents/");
    final request = http.MultipartRequest("POST", uri);
    
    if (token != null) {
      request.headers["Authorization"] = "Bearer $token";
    }

    request.fields["categoria_id"] = categoryId.toString();
    request.fields["descripcion"] = descripcion;
    request.fields["latitud"] = latitud.toString();
    request.fields["longitud"] = longitud.toString();
    request.fields["direccion"] = direccion;

    if (imageFile != null) {
      final multipartFile = await http.MultipartFile.fromPath(
        "file",
        imageFile.path,
      );
      request.files.add(multipartFile);
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> triggerPanic({
    required double latitud,
    required double longitud,
    required String direccion,
  }) async {
    final token = await getToken();
    final uri = Uri.parse("$baseUrl/incidents/panic");
    final request = http.MultipartRequest("POST", uri);
    if (token != null) {
      request.headers["Authorization"] = "Bearer $token";
    }
    request.fields["latitud"] = latitud.toString();
    request.fields["longitud"] = longitud.toString();
    request.fields["direccion"] = direccion;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> updateIncidentStatus(int incidentId, String status, String risk) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse("$baseUrl/incidents/$incidentId"),
      headers: headers,
      body: jsonEncode({"estado": status, "nivel_riesgo": risk}),
    );
    return _processResponse(response);
  }

  // --- NOTIFICACIONES ---

  Future<List<dynamic>> getNotifications() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse("$baseUrl/alerts/notifications"),
      headers: headers,
    );
    final processed = _processResponse(response);
    return processed is List ? processed : [];
  }

  Future<Map<String, dynamic>> markNotificationRead(int notificationId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse("$baseUrl/alerts/notifications/$notificationId/read"),
      headers: headers,
    );
    return _processResponse(response);
  }

  // --- IA Y DASHBOARD ---

  Future<Map<String, dynamic>> predictRisk({
    required double latitud,
    required double longitud,
    required int hora,
    required int diaSemana,
    required int categoryId,
  }) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse("$baseUrl/predictions/predict"),
      headers: headers,
      body: jsonEncode({
        "latitud": latitud,
        "longitud": longitud,
        "hora": hora,
        "dia_semana": diaSemana,
        "categoria_id": categoryId
      }),
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse("$baseUrl/dashboard/stats"),
      headers: headers,
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> retrainModel() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse("$baseUrl/predictions/train"),
      headers: headers,
    );
    return _processResponse(response);
  }

  // --- REPORTES ---

  Future<http.Response> downloadReport({
    required String format,
    int? categoryId,
    String? status,
    String? dateStart,
    String? dateEnd,
  }) async {
    final token = await getToken();
    String query = "?formato=$format";
    if (categoryId != null) query += "&categoria_id=$categoryId";
    if (status != null) query += "&estado=$status";
    if (dateStart != null) query += "&fecha_inicio=$dateStart";
    if (dateEnd != null) query += "&fecha_fin=$dateEnd";

    final response = await http.get(
      Uri.parse("$baseUrl/reports/export$query"),
      headers: {
        if (token != null) "Authorization": "Bearer $token",
      },
    );
    return response;
  }

  Future<Map<String, dynamic>> recoverPassword(String email) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/recover-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"correo": email}),
    );
    return _processResponse(response);
  }

  Future<Map<String, dynamic>> resetPassword(String token, String newPassword) async {
    final response = await http.post(
      Uri.parse("$baseUrl/auth/reset-password"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"token": token, "nueva_contrasena": newPassword}),
    );
    return _processResponse(response);
  }

  Future<List<dynamic>> getAdminUsers() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse("$baseUrl/admin/users"), headers: headers);
    final data = _processResponse(response);
    return data is List ? data : [];
  }

  Future<void> toggleUserStatus(int userId) async {
    final headers = await _getHeaders();
    await http.patch(Uri.parse("$baseUrl/admin/users/$userId/status"), headers: headers);
  }

  Future<void> deleteUser(int userId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse("$baseUrl/admin/users/$userId"), headers: headers);
    _processResponse(response);
  }

  Future<void> updateUserRole(int userId, int roleId) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse("$baseUrl/admin/users/$userId"),
      headers: headers,
      body: jsonEncode({"rol_id": roleId}),
    );
    _processResponse(response);
  }

  // --- PROCESAMIENTO GENERAL ---

  dynamic _processResponse(http.Response response) {
    final body = response.body;
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      decoded = body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    } else {
      String errMsg = "Ocurrió un error inesperado.";
      if (decoded is Map && decoded.containsKey("detail")) {
        errMsg = decoded["detail"];
      }
      throw HttpException(errMsg);
    }
  }
}
