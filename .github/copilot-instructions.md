<!-- Arquivo gerado automaticamente por assistente. Revise antes de commitar. -->
# Instruções rápidas para agentes (Copilot / AI)

Objetivo: orientar edições e intervenções de código neste projeto Flutter de simulação de blockchain.

- **Visão geral:**
  - **UI**: `lib/main.dart` — app Flutter que usa `BlockchainCore` para simular atividades PoAcy/PoC.
  - **Core**: `lib/blockchain_core.dart` — contém a cadeia (`chain`), transações pendentes e `mineBlockPoC()` (algoritmo principal).
  - **Modelos**: `lib/block.dart` e `lib/transaction.dart` — estruturas de dados e hashagem por transação/bloco.
  - **Hashing**: `lib/hashing.dart` — wrapper SHA-256 usando `package:crypto` (ver nota de cuidado abaixo).

- **Fluxo de dados chave**:
  - Chamadas públicas: `createPoAcyTransaction(...)` e `createPoCTransaction(...)` adicionam objetos `Transaction` a `pendingTransactions`.
  - `mineBlockPoC()` reúne `pendingTransactions`, adiciona uma `reward` tx, tenta nonces até satisfazer `difficulty` e adiciona o `Block` à `chain`.
  - Genesis: `_createGenesisBlock()` cria o bloco inicial com `previousHash` preenchido por zeros.

- **Constantes e convenções do projeto**:
  - `initialReward` e `initialDifficulty` em `BlockchainCore` controlam recompensa e dificuldade (ex.: 4 zeros iniciais).
  - `proofType` em `Transaction` usa strings: `ACTIVITY_PROOF`, `COOPERATION_PROOF`, `TOKEN_TRANSFER`.
  - Endereços simulados: `nodeAddress` gerado em `blockchain_core.dart` e destinos como `0xREWARD_SC`.

- **Dependências / integração**:
  - `pubspec.yaml` declara `crypto: ^3.0.0` — usado por `lib/hashing.dart`.
  - Plataformas: projetos de plataforma gerados (`android/`, `ios/`, `linux/`, `macos/`, `windows/`) — builds padrão Flutter aplicam-se.

- **Workflows de desenvolvedor (comandos práticos)**:
  - Obter deps: `flutter pub get`
  - Rodar em dispositivo/emulador: `flutter run -d <device-id>` (ex.: `-d linux`, `-d emulator-5554`)
  - Rodar testes: `flutter test` (há `test/widget_test.dart` como ponto de partida)
  - Build release: `flutter build apk` / `flutter build ios` / `flutter build linux`

- **Notas de depuração e performance (essenciais)**:
  - `mineBlockPoC()` realiza um laço intensivo de `nonce` e escreve logs via `print(...)` a cada 50k tentativas. Execute o app com console aberto para visualizar progresso.
  - Atualmente a mineração é executada de forma síncrona no mesmo isolate; apesar do `main.dart` usar `Future.delayed(Duration.zero)` para evitar bloqueio óbvio, a função `mineBlockPoC()` não está isolada — mudanças pesadas podem congelar a UI. Ao modificar, procure usar `compute`/`Isolate` ou mover mineração para uma Isolate separada.

- **Pontos sensíveis ao editar**:
  - `lib/hashing.dart` contém um wrapper `sha256(String)` que depende de `package:crypto`. Há risco de conflito por nome com o símbolo importado. Ao editar, prefira uma import nomeada: `import 'package:crypto/crypto.dart' as crypto;` e use `crypto.sha256.convert(...)`, ou renomeie a função para `sha256Hex`.
  - Evite alterar o formato das `Transaction` sem atualizar `calculateHash()` em `transaction.dart` — muitos componentes assumem o JSON serializado atual.

- **Como adicionar uma nova transação / experimento rápido**:
  - No código: `unitChain.createPoAcyTransaction(userAddress: unitChain.nodeAddress, source: 'MyAPI', event: 'EVENT', data: {...});`
  - Em seguida chame `unitChain.mineBlockPoC()` para incluí-la no próximo bloco (ou iniciar a UI que chama `startSimulation()` em `main.dart`).

- **Arquivos a revisar primeiro (referência rápida)**:
  - `lib/blockchain_core.dart` — algoritmo PoC e API principal
  - `lib/block.dart`, `lib/transaction.dart` — modelos e hashes
  - `lib/hashing.dart` — implementação SHA-256 (atenção ao nome)
  - `lib/main.dart` — integração UI / exemplo de uso
  - `pubspec.yaml` — dependências e SDK

Nenhuma instrução anterior encontrada no repositório; este arquivo foi criado para centralizar conhecimento detectável. Peça revisão se algo estiver incorreto ou faltando (por ex., outras integrações externas não detectadas localmente).

---
Por favor, indique se quer que eu: (1) adicione exemplos de teste unitário para `BlockchainCore`, (2) crie uma issue descrevendo o possível bug em `hashing.dart`, ou (3) mantenha o arquivo como está e finalize.
