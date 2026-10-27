import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/auth_service.dart';
import 'package:ghydro/login_screen.dart';
import 'package:ghydro/dashboard_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response jsonResponse(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

String testToken(String role) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': 'lucas@example.com', 'nome': 'Lucas', 'role': role}))).replaceAll('=', '')}.signature';

void main() {
  test('Cadastro envia contrato atual; login lê perfil do JWT', () async {
    final requests = <http.Request>[];
    final auth = AuthService(
      api: ApiClient(
        client: MockClient((r) async {
          requests.add(r);
          if (r.url.path == '/auth/register') {
            return jsonResponse({'message': 'Criado'});
          }
          if (r.url.path == '/auth/login') {
            return jsonResponse({'token': testToken('TECNICO')});
          }
          expect(r.headers['Authorization'], 'Bearer test-token');
          return jsonResponse({
            'nome': 'Lucas',
            'email': 'lucas@example.com',
            'role': 'TECNICO',
          });
        }),
      ),
    );
    await auth.register(email: ' LUCAS@example.com ', password: 'senha12345');
    expect(jsonDecode(requests.first.body), {
      'email': 'lucas@example.com',
      'senha': 'senha12345',
      'role': 'PRODUTOR',
    });
    expect(
      await auth.signIn(email: 'lucas@example.com', password: 'senha12345'),
      'Lucas',
    );
    expect(auth.canManage, isTrue);
    expect(auth.canManagePlantings, isTrue);
    auth.signOut();
    expect(auth.api.token, isNull);
    expect(auth.profile, isNull);
  });
  test('Produtor pode gerenciar plantios sem acesso de equipe', () async {
    final auth = AuthService(
      api: ApiClient(
        client: MockClient(
          (_) async => jsonResponse({'token': testToken('PRODUTOR')}),
        ),
      ),
    );
    await auth.signIn(email: 'lucas@example.com', password: 'senha12345');
    expect(auth.canManage, isFalse);
    expect(auth.canManagePlantings, isTrue);
    auth.signOut();
    expect(auth.canManagePlantings, isFalse);
  });
  test('Erro de login não cria sessão nem ignora falha no perfil', () async {
    final auth = AuthService(
      api: ApiClient(
        client: MockClient(
          (r) async => r.url.path == '/auth/login'
              ? jsonResponse({'token': 'token'})
              : jsonResponse({'message': 'Falha'}, 500),
        ),
      ),
    );
    await expectLater(
      auth.signIn(email: 'x@y.com', password: 'password'),
      throwsA(isA<ApiFailure>()),
    );
    expect(auth.api.token, isNull);
    expect(auth.profile, isNull);
  });
  test(
    'Sessão expirada é encerrada uma vez e permissão negada mantém sessão',
    () async {
      var status = 403;
      var logouts = 0;
      final api = ApiClient(
        client: MockClient((_) async => jsonResponse({}, status)),
      )..token = 'token';
      api.onUnauthorized = () => logouts++;
      await expectLater(
        api.list('sensor'),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 403)),
      );
      expect(api.token, 'token');
      status = 401;
      await expectLater(api.list('sensor'), throwsA(isA<ApiFailure>()));
      await expectLater(api.list('sensor'), throwsA(isA<ApiFailure>()));
      expect(logouts, 1);
      expect(api.token, isNull);
    },
  );
  test('Erro de rede é compreensível e resposta vazia é aceita', () async {
    final offline = ApiClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await expectLater(
      offline.list('sensor'),
      throwsA(
        isA<ApiFailure>().having(
          (e) => e.message,
          'message',
          contains('conectar'),
        ),
      ),
    );
    final api = ApiClient(
      client: MockClient((r) async => http.Response('', 204)),
    );
    expect(await api.request('GET', 'sensor'), isNull);
  });
  testWidgets('Cadastro, validação, erro do servidor e entrada no painel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(600, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final auth = AuthService(
      api: ApiClient(
        client: MockClient((r) async {
          if (r.url.path == '/auth/register') {
            return jsonResponse({'message': 'Criado'});
          }
          if (r.url.path == '/auth/login') {
            if (jsonDecode(r.body)['senha'] == 'errada') {
              return jsonResponse({
                'message': 'E-mail ou senha incorretos.',
              }, 401);
            }
            return jsonResponse({'token': testToken('PRODUTOR')});
          }
          return jsonResponse([]);
        }),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: LoginScreen(auth: auth)));
    await tester.ensureVisible(find.text('Crie agora'));
    await tester.tap(find.text('Crie agora'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('email')),
      'lucas@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('password')),
      'senha12345',
    );
    await tester.enterText(find.byKey(const ValueKey('confirm')), 'diferente');
    await tester.ensureVisible(find.text('Criar conta'));
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(find.text('As senhas não coincidem.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('confirm')), 'senha12345');
    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();
    expect(
      find.text('Conta criada! Entre com seu e-mail e senha.'),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const ValueKey('password')), 'errada');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('password')),
      'senha12345',
    );
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.text('Lucas'), findsOneWidget);
    expect(find.text('Seus pivôs e dispositivos'), findsOneWidget);
  });
}
