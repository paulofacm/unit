import 'block.dart';
import 'transaction.dart';
import 'hashing.dart';
import 'wallet.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'miner_isolate.dart';

class BlockchainCore {
  static const double initialReward = 50.0;
  static const int initialDifficulty = 4;
  
  final List<Block> chain = [];
  List<Transaction> pendingTransactions = [];
  final Wallet wallet = Wallet(); 

  BlockchainCore() {
    if (chain.isEmpty) chain.add(_createGenesisBlock());
  }

  Block _createGenesisBlock() {
    var genesis = Block(
      id: 0, timestamp: 0, transactions: [],
      previousHash: "0" * 64, nonce: 0, difficulty: initialDifficulty,
      reward: 0.0, type: "GENESIS", minerAddress: "SYSTEM", hash: "", merkleRoot: "0",
    );
    return genesis.copyWith(hash: genesis.calculateHash());
  }

  Block getLastBlock() => chain.last;

  // Prova de Atividade (PoAcy)
  void createPoAcyTransaction({required String source, required String event}) {
    pendingTransactions.add(Transaction(
      id: "TX${Random().nextInt(999)}", from: wallet.publicKey, to: "REWARD_POOL",
      amount: 0.0, timestamp: DateTime.now().millisecondsSinceEpoch,
      proofType: "ACTIVITY_PROOF", activityData: {"source": source, "event": event},
      signature: calculateSha256(wallet.publicKey + event),
    ));
  }

  // NOVA FUNÇÃO: Transferência de Tokens UNIT
  void createTransfer({required String to, required double amount}) {
    if (wallet.balance < amount) return; // Proteção básica de saldo

    pendingTransactions.add(Transaction(
      id: "SEND${Random().nextInt(999)}", 
      from: wallet.publicKey, 
      to: to,
      amount: amount, 
      timestamp: DateTime.now().millisecondsSinceEpoch,
      proofType: "TOKEN_TRANSFER", 
      signature: calculateSha256(wallet.publicKey + to + amount.toString()),
    ));
  }

  void mineBlockPoC() {
    final previous = getLastBlock();
    final rewardTx = Transaction(
      id: "REW${Random().nextInt(999)}", from: "0xSYSTEM", to: wallet.publicKey,
      amount: initialReward, timestamp: DateTime.now().millisecondsSinceEpoch,
      proofType: "TOKEN_TRANSFER", signature: "SYS_SIG",
    );

    var candidate = Block(
      id: previous.id + 1, timestamp: DateTime.now().millisecondsSinceEpoch,
      transactions: [...pendingTransactions, rewardTx],
      previousHash: previous.hash, nonce: 0, difficulty: initialDifficulty,
      reward: initialReward, type: "PoC L1", minerAddress: wallet.publicKey,
      hash: "", merkleRoot: "MERKLE_STUB",
    );

    final target = "0" * initialDifficulty;
    String h;
    do {
      candidate = candidate.copyWith(nonce: candidate.nonce + 1);
      h = candidate.calculateHash();
    } while (!h.startsWith(target));

    chain.add(candidate.copyWith(hash: h));
    pendingTransactions.clear();
  }

  /// Versão não bloqueante da mineração usando `compute`.
  Future<Block> mineBlockPoCAsync() async {
    final previous = getLastBlock();
    final nextId = previous.id + 1;
    final minerReward = initialReward;

    final txs = List<Transaction>.from(pendingTransactions);
    final rewardTx = Transaction(
      id: "TX${Random().nextInt(999999)}",
      from: "0xSYSTEM",
      to: wallet.publicKey,
      amount: minerReward,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      proofType: "TOKEN_TRANSFER",
      signature: calculateSha256("SYSTEM_REWARD"),
    );
    txs.add(rewardTx);

    final candidate = Block(
      id: nextId,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      transactions: txs,
      previousHash: previous.hash,
      nonce: 0,
      difficulty: previous.difficulty,
      reward: minerReward,
      type: "PoC L1 HUB",
      minerAddress: wallet.publicKey,
      hash: "",
      merkleRoot: "STUB",
    );

    final args = {'blockTemplate': candidate.toJson(), 'difficulty': previous.difficulty};
    final minedMap = await compute(mineWorker, args);
    final mined = Block.fromJson(minedMap);
    chain.add(mined);
    pendingTransactions.clear();
    return mined;
  }
}