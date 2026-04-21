import 'dart:convert';
import 'package:bionotary/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl => AppConfig.resolvedApiBaseUrl;
  static final storage = FlutterSecureStorage();

  static Future<String?> _getToken() async {
    return await storage.read(key: 'jwt');
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw Exception(data['message']?.toString() ?? response.body);
    }
    return data;
  }

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
      final storedEmail =
          data['email'] as String? ??
          (data['user'] is Map
              ? (data['user'] as Map)['email'] as String?
              : null) ??
          email;
      await storage.write(key: 'user_email', value: storedEmail);
    }
    return data;
  }

  static Future<Map<String, dynamic>> fingerprintLogin() async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/fingerprint/login'),
      headers: {'Content-Type': 'application/json'},
      body: '{}',
    );
    Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      data = {'message': response.body};
    }
    if (response.statusCode == 200 && data['token'] != null) {
      await storage.write(key: 'jwt', value: data['token'] as String);
      final email = data['email'] as String? ?? '';
      await storage.write(key: 'user_email', value: email);
    }
    return data;
  }

  static Future<Map<String, dynamic>> enrollFingerprint() async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('JWT missing. Please log in again.');
    }
    final response = await http.post(
      Uri.parse('$baseUrl/auth/fingerprint/enroll'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: '{}',
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(data['message']?.toString() ?? response.body);
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

  /// Registered document + on-chain anchor for this user, if any.
  static Future<Map<String, dynamic>?> lookupDocumentByHash(String sha256Hex) async {
    final token = await _getToken();
    if (token == null || token.isEmpty) {
      throw Exception('JWT missing. Please log in again.');
    }
    final clean = sha256Hex.replaceFirst(RegExp(r'^0x'), '').trim();
    final response = await http.get(
      Uri.parse('$baseUrl/documents/lookup-by-hash?sha256=$clean'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode != 200) {
      throw Exception('Lookup failed: ${response.body}');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['document'] as Map<String, dynamic>?;
  }
}
