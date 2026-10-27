import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Fotos são locais ao navegador/dispositivo e identificadas pela conta.
class ProfilePhotoService {
  ProfilePhotoService({
    ImagePicker? picker,
    SharedPreferencesAsync? preferences,
  }) : _picker = picker ?? ImagePicker(),
       _providedPreferences = preferences;

  final ImagePicker _picker;
  final SharedPreferencesAsync? _providedPreferences;
  late final SharedPreferencesAsync _preferences =
      _providedPreferences ?? SharedPreferencesAsync();
  static const maxBytes = 512 * 1024;

  String _key(String email) =>
      'ghydro.profile_photo.${base64Url.encode(utf8.encode(email.trim().toLowerCase()))}';

  Future<Uint8List?> load(String email) async {
    final encoded = await _preferences.getString(_key(email));
    if (encoded == null || encoded.length > maxBytes * 2) return null;
    try {
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty || bytes.length > maxBytes) return null;
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> chooseAndSave(String email) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (file == null) return null;
    if (await file.length() > maxBytes) {
      throw const ProfilePhotoFailure('Escolha uma imagem de até 512 KB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const ProfilePhotoFailure('Escolha uma imagem de até 512 KB.');
    }
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      codec.dispose();
    } catch (_) {
      throw const ProfilePhotoFailure('Não foi possível abrir essa imagem.');
    }
    await _preferences.setString(_key(email), base64Encode(bytes));
    return bytes;
  }

  Future<void> remove(String email) => _preferences.remove(_key(email));
}

class ProfilePhotoFailure implements Exception {
  const ProfilePhotoFailure(this.message);
  final String message;
  @override
  String toString() => message;
}
