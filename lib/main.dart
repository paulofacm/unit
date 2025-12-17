import 'package:flutter/material.dart';
import 'blockchain_core.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: SimulationScreen()
));

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});
  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final BlockchainCore core = BlockchainCore();
  final TextEditingController _addrController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool isMining = false;

  void startMining() async {
    setState(() => isMining = true);
    core.createPoAcyTransaction(source: "YouTube", event: "Watch_Video");
    
    // Executa a mineração PoC assincrona em Isolate/compute
    final mined = await core.mineBlockPoCAsync();
    
    setState(() {
      core.wallet.updateBalance(core);
      isMining = false;
    });
  }

  void executeTransfer() {
    double? val = double.tryParse(_amountController.text);
    if (val != null && _addrController.text.isNotEmpty) {
      setState(() {
        core.createTransfer(to: _addrController.text, amount: val);
        core.wallet.updateBalance(core);
      });
      _amountController.clear();
      _addrController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Transação enviada para a fila de mineração!"))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UNIT Network - PoC & Wallet'),
        backgroundColor: Colors.blueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Card de Saldo
            Card(
              elevation: 4,
              color: Colors.blue.shade50,
              child: ListTile(
                title: const Text("SALDO TOTAL", style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text("${core.wallet.balance.toStringAsFixed(2)} 💎", 
                  style: const TextStyle(fontSize: 22, color: Colors.blue, fontWeight: FontWeight.bold)),
                subtitle: SelectableText("Sua Chave: ${core.wallet.publicKey}"),
              ),
            ),
            const SizedBox(height: 20),

            // Formulário de Envio
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
              ),
              child: Column(
                children: [
                  const Text("TRANSFERIR UNITs", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(controller: _addrController, decoration: const InputDecoration(labelText: "Endereço do Destino (0x...)")),
                  TextField(controller: _amountController, decoration: const InputDecoration(labelText: "Valor"), keyboardType: TextInputType.number),
                  const SizedBox(height: 10),
                  ElevatedButton(onPressed: executeTransfer, child: const Text("ENVIAR UNIT")),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Botão de Minerar
            ElevatedButton.icon(
              onPressed: isMining ? null : startMining,
              icon: const Icon(Icons.settings_applications),
              label: Text(isMining ? "MINERANDO BLOCO..." : "GERAR BLOCO PoC"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: isMining ? Colors.grey : Colors.orange,
                foregroundColor: Colors.white
              ),
            ),

            const Divider(height: 40),
            const Text("LOG DA BLOCKCHAIN", style: TextStyle(fontWeight: FontWeight.bold)),
            
            // Lista de Blocos
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: core.chain.length,
              itemBuilder: (context, index) {
                final b = core.chain[index];
                return ExpansionTile(
                  leading: CircleAvatar(child: Text("${b.id}")),
                  title: Text("Hash: ${b.hash.substring(0, 12)}..."),
                  subtitle: Text("Nonce: ${b.nonce}"),
                  children: b.transactions.map((tx) => ListTile(
                    dense: true,
                    title: Text("${tx.proofType} | ${tx.amount} UNIT"),
                    subtitle: Text("Para: ${tx.to}"),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}