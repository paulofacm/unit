import 'dart:convert';
import 'hashing.dart';

class Transaction {
  final String id;
  final String from;   
  final String to;     
  final double amount; 
  final int timestamp;
  final String proofType; 
  final Map<String, dynamic>? activityData; 
  final String? cooperationHash; 
  final String signature; 

  Transaction({
    required this.id, required this.from, required this.to, required this.amount,
    required this.timestamp, required this.proofType,
    this.activityData, this.cooperationHash, required this.signature,
  });

  String calculateHash() {
    final payload = {
      'id': id, 'from': from, 'to': to, 'amount': amount,
      'timestamp': timestamp, 'proofType': proofType,
      'activityData': activityData, 'cooperationHash': cooperationHash,
      'signature': signature,
    };
    // Converte o objeto em uma string JSON para o hashing
    final jsonString = json.encode(payload);
    return sha256Hex(jsonString);
  }

  // Serialização para enviar entre isolates / salvar em IndexedDB
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from,
      'to': to,
      'amount': amount,
      'timestamp': timestamp,
      'proofType': proofType,
      'activityData': activityData,
      'cooperationHash': cooperationHash,
      'signature': signature,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] as String,
      from: json['from'] as String,
      to: json['to'] as String,
      amount: (json['amount'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      proofType: json['proofType'] as String,
      activityData: json['activityData'] != null ? Map<String, dynamic>.from(json['activityData']) : null,
      cooperationHash: json['cooperationHash'] as String?,
      signature: json['signature'] as String,
    );
  }
}