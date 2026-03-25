import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static final String baseUrl = kIsWeb
      ? 'http://localhost:5000'
      : 'http://10.0.2.2:5000';
  static final storage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await storage.read(key: 'jwt');
  }

  /// Login and store JWT. Call this when backend returns { "token": "..." }.
  /// Also stores email from response, or the login email if not in response.
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['token'] != null) {
      await storage.write(key: 'jwt', value: data['token'] as String);
      final storedEmail = data['email'] as String? ??
          (data['user'] is Map ? (data['user'] as Map)['email'] as String? : null) ??
          email;
      await storage.write(key: 'user_email', value: storedEmail);
    }
    return data;
  }

  static Future<void> logout() async {
    await storage.delete(key: 'jwt');
    await storage.delete(key: 'user_email');
  }

  static Future<String?> getStoredUserEmail() async {
    return await storage.read(key: 'user_email');
  }

  static Future<bool> hasToken() async {
    final token = await _getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, dynamic>> createDocument({
    required String fileName,
    required String fileType,
    required int fileSize,
    required String sha256,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('JWT missing. Please log in again.');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/documents'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'file_name': fileName,
        'file_type': fileType,
        'file_size': fileSize,
        'sha256_hash': sha256,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createNotarization({
    required String documentId,
    required String txHash,
    required String contractAddress,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('JWT missing. Please log in again.');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/notarizations'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'document_id': documentId,
        'transaction_hash': txHash,
        'blockchain_network': 'sepolia',
        'contract_address': contractAddress,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<void> saveApplicantDetails({
    required String firstName,
    required String middleName,
    required String lastName,
    required String aadhaar,
    required String email,
    required String pan,
    required String phone,
  }) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/applicants'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'first_name': firstName,
        'middle_name': middleName.isEmpty ? null : middleName,
        'last_name': lastName,
        'aadhaar': aadhaar,
        'email': email,
        'pan': pan.isEmpty ? null : pan,
        'phone': phone.isEmpty ? null : phone,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save applicant: ${response.body}');
    }
  }

  /// GET /documents/my-documents — list of user's documents with notarization.
  static Future<List<dynamic>> getMyDocuments() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('JWT missing. Please log in again.');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/documents/my-documents'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load documents: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = data['documents'] as List<dynamic>? ?? [];
    return docs;
  }
}
