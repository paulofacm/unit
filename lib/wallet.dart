import 'blockchain_core.dart';
import 'hashing.dart';
import 'dart:math';

class Wallet {
  final String publicKey; 
  final String privateKey; 
  double balance = 0.0;

  Wallet()
      : publicKey = "0x${sha256Hex(DateTime.now().toString() + Random().nextDouble().toString()).substring(0, 16)}",
        privateKey = sha256Hex("private_${DateTime.now().toIso8601String()}");

  void updateBalance(BlockchainCore core) {
    double tempBalance = 0.0;
    for (var block in core.chain) {
      for (var tx in block.transactions) {
        // Se a transação foi enviada PARA você, soma ao saldo
        if (tx.to == publicKey) {
          tempBalance += tx.amount;
        }
        // Se a transação partiu de você (Transferência), subtrai do saldo
        if (tx.from == publicKey && tx.proofType == "TOKEN_TRANSFER") {
          tempBalance -= tx.amount;
        }
      }
    }
    balance = tempBalance;
  }
}