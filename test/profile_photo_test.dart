import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ghydro/api_client.dart';
import 'package:ghydro/auth_service.dart';
import 'package:ghydro/dashboard_screen.dart';
import 'package:ghydro/profile_photo_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class FakePicker extends ImagePicker {
  XFile? file;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async => file;
}

class FakePhotoService extends ProfilePhotoService {
  final Map<String, Uint8List> photos = {};
  Uint8List? selection;
  @override
  Future<Uint8List?> load(String email) async => photos[email];
  @override
  Future<Uint8List?> chooseAndSave(String email) async {
    if (selection != null) photos[email] = selection!;
    return selection;
  }

  @override
  Future<void> remove(String email) async => photos.remove(email);
}

void main() {
  testWidgets('Foto local persiste por conta e pode ser removida', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    final bytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/6S4AAAAASUVORK5CYII=',
    );
    final picker = FakePicker()
      ..file = XFile.fromData(bytes, mimeType: 'image/png');
    final service = ProfilePhotoService(picker: picker);
    expect(await service.chooseAndSave('Lucas@example.com'), bytes);
    expect(await service.load('lucas@example.com'), bytes);
    expect(await service.load('outra@example.com'), isNull);
    picker.file = null;
    expect(await service.chooseAndSave('lucas@example.com'), isNull);
    expect(await service.load('lucas@example.com'), bytes);
    picker.file = XFile.fromData(Uint8List(ProfilePhotoService.maxBytes + 1));
    await expectLater(service.chooseAndSave('lucas@example.com'), throwsA(isA<ProfilePhotoFailure>()));
    expect(await service.load('lucas@example.com'), bytes);
    await service.remove('lucas@example.com');
    expect(await service.load('lucas@example.com'), isNull);
  });
  testWidgets('Perfil adiciona e remove foto apenas da conta selecionada', (
    tester,
  ) async {
    final photos = FakePhotoService()
      ..selection = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/6S4AAAAASUVORK5CYII=',
      );
    final auth = AuthService(
      api: ApiClient(client: MockClient((_) async => http.Response('[]', 200))),
    )..profile = {'nome': 'Lucas', 'role': 'PRODUTOR'};
    await tester.pumpWidget(
      MaterialApp(
        home: DashboardScreen(
          auth: auth,
          name: 'Lucas',
          email: 'lucas@example.com',
          onLogout: (_) {},
          photoService: photos,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar foto'));
    await tester.pumpAndSettle();
    expect(photos.photos['lucas@example.com'], isNotNull);
    expect(photos.photos['outra@example.com'], isNull);
    expect(find.text('Alterar foto'), findsOneWidget);
    expect(
      find.text('A foto fica salva somente neste dispositivo.'),
      findsNothing,
    );
    await tester.tap(find.text('Remover foto'));
    await tester.pumpAndSettle();
    expect(photos.photos, isEmpty);
    expect(find.text('Adicionar foto'), findsOneWidget);
  });
}
