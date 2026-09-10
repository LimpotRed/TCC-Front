import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_validation.dart';

// Define como ler e gravar contas. Podemos trocar o armazenamento
// sem precisar mudar os campos da tela.
abstract class AccountStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

// Salva as contas no navegador usado para abrir o app.
class BrowserAccountStore implements AccountStore {
  final _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}

// Cuida do cadastro e do login. As contas ficam no próprio aparelho.
// Para acessar a mesma conta em outro aparelho, será preciso um servidor.
class AuthService {
  AuthService({AccountStore? store, this.iterations = 600000})
    : _store = store ?? BrowserAccountStore();

  final AccountStore _store;
  final int iterations;

  // Evita criar contas diferentes por causa de maiúsculas ou espaços.
  String _accountKey(String email) =>
      'ghydro.account.v1.${email.trim().toLowerCase()}';
  List<int> _randomBytes(int count) {
    final random = Random.secure();
    return List.generate(count, (_) => random.nextInt(256));
  }

  // Gera um hash para comparar no login, sem gravar a senha original.
  // O salt aleatório faz senhas iguais gerarem hashes diferentes.
  Future<String> _hash(String value, String salt, int rounds) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: rounds,
      bits: 256,
    ).deriveKeyFromPassword(password: value, nonce: base64Decode(salt));
    return base64Encode(await key.extractBytes());
  }

  // Converte o texto JSON salvo em um mapa com os dados da conta.
  Future<Map<String, dynamic>?> _read(String email) async {
    final data = await _store.read(_accountKey(email));
    return data == null ? null : jsonDecode(data) as Map<String, dynamic>;
  }

  Future<void> _save(String email, Map<String, dynamic> account) =>
      _store.write(_accountKey(email), jsonEncode(account));

  // Confere os campos e impede e-mails duplicados antes de salvar.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final error =
        validateName(name) ??
        validateEmail(email) ??
        validateNewPassword(password);
    if (error != null) throw AuthFailure(error);
    if (await _read(email) != null) {
      throw const AuthFailure(
        'Este e-mail já está cadastrado. Entre com sua senha.',
      );
    }
    final salt = base64Encode(_randomBytes(16));
    await _save(email, {
      'name': name.trim(),
      'salt': salt,
      'iterations': iterations,
      'passwordHash': await _hash(password, salt, iterations),
    });
  }

  // Confere a senha e devolve o nome para o cabeçalho do painel.
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final account = await _read(email);
    if (account == null ||
        await _hash(
              password,
              account['salt'] as String,
              account['iterations'] as int,
            ) !=
            account['passwordHash']) {
      throw const AuthFailure('E-mail ou senha incorretos.');
    }
    return account['name'] as String;
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
}
