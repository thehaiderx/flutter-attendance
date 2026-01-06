import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://attendence-system-backend-main-unbrad.laravel.cloud/api'; 

  static Future<http.Response> post(String endpoint, Map data) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      body: jsonEncode(data),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }

  static Future<http.Response> get(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token');

    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
  }
}