import 'api_client.dart';
import 'auth_validation.dart';
export 'api_client.dart' show ApiFailure;

class AuthService {
  AuthService({ApiClient? api}) : api = api ?? ApiClient();
  final ApiClient api;
  Map<String, dynamic>? profile;
  bool get canManage => ['ADMIN', 'TECNICO'].contains(profile?['role']);
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final error =
        validateName(name) ??
        validateEmail(email) ??
        validateNewPassword(password);
    if (error != null) throw ApiFailure(error);
    await api.request(
      'POST',
      'auth/register',
      body: {
        'nome': name.trim(),
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
    api.token = response['token'] as String;
    try {
      profile = Map<String, dynamic>.from(
        await api.request('GET', 'auth/me') as Map,
      );
      return profile!['nome'] as String;
    } catch (_) {
      signOut();
      rethrow;
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
