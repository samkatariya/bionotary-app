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
    }
    return data;
  }

  static Future<void> logout() async {
    await storage.delete(key: 'jwt');
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

  /// GET /documents/my-documents — list of user's documents with notarization.
  static Future<List<dynamic>> getMyDocuments() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/documents/my-documents'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load documents: ${response.body}');
    }
    return jsonDecode(response.body) as List<dynamic>;
  }
}
