# GPG + CI: Gerar chaves, adicionar secrets e testar assinaturas

Este documento traz comandos práticos para gerar uma chave GPG, exportar a chave privada (ASCII-armored), adicionar os secrets no GitHub via `gh` CLI e testar a assinatura/verificação localmente. Use-os com cuidado: a chave privada deve ser mantida segura e os secrets devem ser concedidos apenas ao pipeline de Actions que precisa assinar artefatos.

Pré-requisitos

- `gpg` instalado (GNU Privacy Guard)
- `gh` (GitHub CLI) autenticado com permissão para alterar secrets no repositório
- `npm`/`node` e `pkg` para builds locais (opcional, apenas para reproduzir build)

1) Gerar uma chave GPG (interativo - recomendado)

```bash
gpg --full-generate-key
```

Siga prompts para escolher RSA, tamanho (3072/4096 recomendado), nome e e-mail. Opcionalmente defina uma passphrase.

2) Localizar `KEY_ID` recém-criado

```bash
gpg --list-secret-keys --keyid-format LONG
# ex.: /home/user/.gnupg/secring.gpg
# sec   rsa4096/0123456789ABCDEF 2025-12-17 [SC]
#       0123456789ABCDEF

# Extraia o ID (0123456789ABCDEF):
KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | awk '/sec/{print $2}' | cut -d'/' -f2 | head -n1)
echo "$KEY_ID"
```

3) Exportar a chave privada ASCII-armored para um arquivo (não compartilhe o arquivo)

```bash
gpg --armor --export-secret-keys "$KEY_ID" > relayer_gpg_priv.asc
```

4) (Opcional) Limpar key export do disco de forma segura

```bash
# Se disponível: shred -u relayer_gpg_priv.asc
# Caso contrário, apague normalmente e só mantenha em local seguro até adicionar aos secrets
```

5) Adicionar secrets no GitHub (via `gh` CLI)

Obs: execute estes comandos no diretório do repositório local ou passe `--repo owner/repo`.

```bash
# Requer gh autenticado com permissão de escrita no repo
gh secret set GPG_PRIVATE_KEY --body "$(cat relayer_gpg_priv.asc)"
# Se sua chave tiver passphrase, adicione também
gh secret set GPG_PASSPHRASE --body "<SUA_PASSPHRASE_AQUI>"

# Verifique que os secrets existem
gh secret list
```

6) Como o workflow usa os secrets

- A workflow importa `GPG_PRIVATE_KEY` em tempo de execução para um `GNUPGHOME` temporário e usa `gpg --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE"` para assinar os arquivos gerados (detached signatures). O nome dos secrets usados no workflow do repositório é `GPG_PRIVATE_KEY` e `GPG_PASSPHRASE`.

7) Testar localmente: import temporário e assinatura (sem poluir seu keyring)

```bash
# importe a chave para um GNUPGHOME temporário
export GNUPGHOME="$(mktemp -d)"
gpg --batch --import relayer_gpg_priv.asc

# encontre KEY_ID no GNUPGHOME temporário
KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | awk '/sec/{print $2}' | cut -d'/' -f2 | head -n1)

# supondo que você já rodou a build e existe dist/CHECKSUMS
gpg --batch --yes --pinentry-mode loopback --passphrase "$GPG_PASSPHRASE" --output dist/CHECKSUMS.sig --detach-sign dist/CHECKSUMS

# verificar a assinatura
gpg --verify dist/CHECKSUMS.sig dist/CHECKSUMS

# cleanup: remova o GNUPGHOME temporário
rm -rf "$GNUPGHOME"
```

Se preferir não colocar a passphrase no ambiente, gere uma chave sem passphrase (não recomendado para chaves long-lived) ou use um agente/flow de CI que interaja com hardware HSM.

8) Remoção segura do arquivo exportado

```bash
shred -u relayer_gpg_priv.asc || rm -f relayer_gpg_priv.asc
```

9) Observações de segurança

- Nunca exponha `relayer_gpg_priv.asc` publicamente.
- GitHub Actions Secrets são seguros para uso em CI, mas minimize quem pode editar workflows e acessar secrets.
- Considere usar um HSM/Cloud KMS para chaves de assinatura de produção.

Se quiser, eu posso:

- (A) Atualizar o workflow para usar uma Action já existente que importa GPG com mais controles; ou
- (B) Criar um PR com este arquivo e as alterações que fizmos nos scripts/workflow.

— Fim —
