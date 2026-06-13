import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Emulator Android:
  // static const String baseUrl = 'http://10.0.2.2:5000';

  // Telefon:
  // static const String baseUrl = 'http://192.168.1.100:5000';

  // Na razie localhost:
  static const String baseUrl = 'https://ai.darkstarlight.eu';

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_name': username,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      throw Exception('INVALID_CREDENTIALS');
    }

    if (response.statusCode == 400) {
      throw Exception('INVALID_DATA');
    }

    throw Exception('LOGIN_ERROR');
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_name': username,
        'password': password,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 409) {
      throw Exception('USER_EXISTS');
    }

    if (response.statusCode == 400) {
      throw Exception('INVALID_DATA');
    }

    throw Exception('REGISTER_ERROR');
  }

  static Future<Map<String, dynamic>> getUser(
      int userId,
      ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load user');
  }

  static Future<Map<String, dynamic>> getStats(
      int userId,
      ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/stats'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load stats');
  }

  static Future<List<dynamic>> getLeaderboard({
    int limit = 10,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/leaderboard?n=$limit'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return data['top'];
    }

    throw Exception('Failed to load leaderboard');
  }

  static Future<Map<String, dynamic>> saveGame({
    required int userId,
    required int points,
    required int length,
    required bool won,
    int? livesLeft,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/games'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
        'points': points,
        'length': length,
        'won': won,
        'lives_left': livesLeft,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to save game');
  }

  static Future<Map<String, dynamic>> getWeeklyStats(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/stats/weekly'),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Failed to load weekly stats');
  }

  static Future<double> getAverageLast7Days() async {
    final response = await http.get(
      Uri.parse('$baseUrl/stats/avg7d'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      return (data['avg_points_last_7d'] as num).toDouble();
    }

    throw Exception('Failed to load average stats');
  }

  static Future<Map<String, dynamic>> predictGesture(
      List<List<double>> points,
      ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/getPrediction'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'points': points,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception('Prediction failed');
  }

  static Future<bool> healthCheck() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      );

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}