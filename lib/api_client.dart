import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    http.Client? client,
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8081',
    ),
  }) : _client = client ?? http.Client();
  final http.Client _client;
  final String baseUrl;
  String? token;
  void Function()? onUnauthorized;

  Future<dynamic> request(String method, String path, {Object? body}) async {
    final sentToken = token;
    try {
      final request = http.Request(
        method,
        Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/$path'),
      );
      request.headers['Content-Type'] = 'application/json; charset=utf-8';
      if (sentToken != null) {
        request.headers['Authorization'] = 'Bearer $sentToken';
      }
      if (body != null) request.body = jsonEncode(body);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 25));
      final text = utf8.decode(response.bodyBytes);
      dynamic data;
      try {
        data = text.isEmpty ? null : jsonDecode(text);
      } catch (_) {
        data = text;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) return data;
      if (response.statusCode == 401 &&
          sentToken != null &&
          token == sentToken) {
        token = null;
        onUnauthorized?.call();
      }
      final fallback = switch (response.statusCode) {
        401 =>
          path == 'auth/login'
              ? 'E-mail ou senha incorretos.'
              : 'Sua sessão expirou. Entre novamente.',
        403 => 'Seu perfil não permite esta operação.',
        404 => 'Registro não encontrado. Atualize a lista.',
        409 => 'O registro está vinculado a outros dados ou já existe.',
        _ => 'Não foi possível concluir a operação. Tente novamente.',
      };
      throw ApiFailure(
        data is Map && data['message'] is String
            ? data['message'] as String
            : fallback,
        status: response.statusCode,
      );
    } on TimeoutException {
      throw const ApiFailure(
        'O servidor demorou para responder. Tente novamente.',
      );
    } on http.ClientException {
      throw const ApiFailure(
        'Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> list(String path) async {
    final data = await request('GET', path);
    if (data is! List) {
      throw const ApiFailure('O servidor retornou uma lista inválida.');
    }
    return data.map((row) => Map<String, dynamic>.from(row as Map)).toList();
  }
}
