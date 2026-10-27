import 'dart:convert';

import 'api_client.dart';
import 'auth_validation.dart';
export 'api_client.dart' show ApiFailure;

class AuthService {
  AuthService({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;
  Map<String, dynamic>? profile;
  bool get canManage => ['ADMIN', 'TECNICO'].contains(profile?['role']);
  bool get canManagePlantings =>
      ['ADMIN', 'TECNICO', 'PRODUTOR'].contains(profile?['role']);
  Future<void> register({
    required String email,
    required String password,
  }) async {
    final error = validateEmail(email) ?? validateNewPassword(password);
    if (error != null) throw ApiFailure(error);
    await api.request(
      'POST',
      'auth/register',
      body: {
        'email': email.trim().toLowerCase(),
        'senha': password,
        'role': 'PRODUTOR',
      },
    );
  }

  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final response = await api.request(
      'POST',
      'auth/login',
      body: {'email': email.trim().toLowerCase(), 'senha': password},
    );
    if (response is! Map || response['token'] is! String) {
      throw const ApiFailure('Resposta de autenticação inválida.');
    }
    final token = response['token'] as String;
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException();
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (claims is! Map ||
          claims['sub'] is! String ||
          claims['role'] is! String) {
        throw const FormatException();
      }
      final name = claims['nome'];
      profile = {
        'nome': name is String && name.trim().isNotEmpty ? name : claims['sub'],
        'email': claims['sub'],
        'role': claims['role'],
      };
      api.token = token;
      return profile!['nome'] as String;
    } catch (_) {
      signOut();
      throw const ApiFailure('Resposta de autenticação inválida.');
    }
  }

  void signOut() {
    api.token = null;
    profile = null;
  }
}
