import 'transaction.dart';
import 'hashing.dart';

class Block {
  final int id;
  final int timestamp;
  final List<Transaction> transactions;
  final String previousHash;
  final int nonce; 
  final int difficulty;
  final double reward;
  final String type;
  final String minerAddress;
  final String hash;
  final String merkleRoot; 

  Block({
    required this.id, required this.timestamp, required this.transactions,
    required this.previousHash, required this.nonce, required this.difficulty,
    required this.reward, required this.type, required this.minerAddress,
    required this.hash, required this.merkleRoot,
  });

  String calculateHash() {
    final txs = transactions.map((t) => t.calculateHash()).join('');
    final input = "$id$timestamp$previousHash$nonce$difficulty$type$merkleRoot$minerAddress$reward$txs"; 
    return calculateSha256(input);
  }
    Map<String, dynamic> toJson() {
      return {
        'id': id,
        'timestamp': timestamp,
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'previousHash': previousHash,
        'nonce': nonce,
        'difficulty': difficulty,
        'reward': reward,
        'type': type,
        'minerAddress': minerAddress,
        'hash': hash,
        'merkleRoot': merkleRoot,
      };
    }

    factory Block.fromJson(Map<String, dynamic> json) {
      return Block(
        id: json['id'] as int,
        timestamp: json['timestamp'] as int,
        transactions: (json['transactions'] as List).map((e) => Transaction.fromJson(Map<String, dynamic>.from(e))).toList(),
        previousHash: json['previousHash'] as String,
        nonce: json['nonce'] as int,
        difficulty: json['difficulty'] as int,
        reward: (json['reward'] as num).toDouble(),
        type: json['type'] as String,
        minerAddress: json['minerAddress'] as String,
        hash: json['hash'] as String,
        merkleRoot: json['merkleRoot'] as String,
      );
    }

  Block copyWith({int? nonce, String? hash}) {
    return Block(
      id: id, timestamp: timestamp, transactions: transactions,
      previousHash: previousHash, nonce: nonce ?? this.nonce,
      difficulty: difficulty, reward: reward, type: type,
      minerAddress: minerAddress, hash: hash ?? this.hash, merkleRoot: merkleRoot,
    );
  }
}