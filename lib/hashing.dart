import 'dart:convert';
import 'package:crypto/crypto.dart' as crypto;

// Retorna o SHA-256 em hex (nome explícito para evitar colisões)
String sha256Hex(String input) {
  final bytes = utf8.encode(input);
  final digest = crypto.sha256.convert(bytes);
  return digest.toString();
}

// Alias legível/compatível com o código pré-existente
String calculateSha256(String input) => sha256Hex(input);