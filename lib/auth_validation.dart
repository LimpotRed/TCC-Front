import 'dart:convert';

// Retorna uma mensagem quando o campo precisa ser corrigido.
// null indica que o campo pode ser aceito.
String? validateEmail(String? value) {
  if (value == null ||
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
    return 'Informe um e-mail válido.';
  }
  return null;
}

// Ignora espaços nas pontas para não aceitar um nome vazio.
String? validateName(String? value) {
  if (value == null || value.trim().length < 2) {
    return 'Informe seu nome.';
  }
  return null;
}

// Esta regra vale para novas contas; o login confere a senha já salva.
String? validateNewPassword(String? value) {
  if (value == null || value.length < 8) {
    return 'Use pelo menos 8 caracteres.';
  }
  if (utf8.encode(value).length > 72) {
    return 'A senha é muito longa (máximo de 72 bytes).';
  }
  return null;
}
