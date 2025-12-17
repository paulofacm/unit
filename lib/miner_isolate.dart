import 'dart:convert';
import 'hashing.dart';

// Entrada para o isolate/compute: espera um Map com o template do bloco
// e a dificuldade alvo.
// Retorna um Map representando o bloco minerado.
Map<String, dynamic> _createCandidate(Map<String, dynamic> template, int nonce) {
  final candidate = Map<String, dynamic>.from(template);
  candidate['nonce'] = nonce;
  return candidate;
}

// Função top-level usada por `compute` (deve aceitar um único argumento).
// args: { 'blockTemplate': Map, 'difficulty': int }
Future<Map<String, dynamic>> mineWorker(Map<String, dynamic> args) async {
  final Map<String, dynamic> template = Map<String, dynamic>.from(args['blockTemplate']);
  final int difficulty = args['difficulty'] as int;
  final String target = '0' * difficulty;

  int nonce = template['nonce'] as int? ?? 0;
  String hashResult = '';

  do {
    nonce++;
    final candidate = _createCandidate(template, nonce);
    final input = json.encode(candidate);
    hashResult = sha256Hex(input);
  } while (!hashResult.startsWith(target));

  final mined = Map<String, dynamic>.from(template);
  mined['nonce'] = nonce;
  mined['hash'] = hashResult;
  return mined;
}
