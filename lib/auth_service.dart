import 'dart:convert';

import 'api_client.dart';
export 'api_client.dart' show ApiFailure;

class AuthService {
  AuthService({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;
  Map<String, dynamic>? profile;
  bool get canManage => ['ADMIN', 'TECNICO'].contains(profile?['role']);
  bool get canManagePlantings =>
      ['ADMIN', 'TECNICO', 'PRODUTOR'].contains(profile?['role']);
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
    api.token = response['token'] as String;
    try {
      // A API atual não expõe /auth/me. O servidor valida o token antes de
      // os dados do JWT serem usados na interface. A autorização continua
      // sendo responsabilidade do backend e a role pode estar desatualizada.
      final accepted = await api.request('GET', 'dominios/moedas');
      if (accepted is! List) {
        throw const ApiFailure('Resposta de autenticação inválida.');
      }
      profile = _profileFromToken(api.token!);
      return profile!['nome'] as String;
    } catch (_) {
      signOut();
      rethrow;
    }
  }

  Map<String, dynamic> _profileFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw const FormatException();
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map ||
          payload['sub'] is! String ||
          (payload['sub'] as String).trim().isEmpty ||
          !['ADMIN', 'TECNICO', 'PRODUTOR'].contains(payload['role'])) {
        throw const FormatException();
      }
      final email = (payload['sub'] as String).trim();
      final name = payload['nome'];
      return {
        'nome': name is String && name.trim().isNotEmpty ? name.trim() : email,
        'email': email,
        'role': payload['role'],
      };
    } on FormatException {
      throw const ApiFailure('Resposta de autenticação inválida.');
    }
  }

  Future<void> updateProfile(String name, String cpf) async {
    profile = Map<String, dynamic>.from(
      await api.request(
        'PUT',
        'auth/me',
        body: {'nome': name.trim(), 'cpf': cpf},
      ) as Map,
    );
  }

  void signOut() {
    api.token = null;
    profile = null;
  }
}
