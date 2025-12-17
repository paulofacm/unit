UNIT Relayer (Signaling Server)

This is a minimal WebSocket signaling server skeleton used for peer discovery and WebRTC signaling between browser nodes in the UNIT prototype.

Usage

Install dependencies and run:

```bash
cd tools/relayer
npm install
npm start
```

Protocol (JSON messages)
- Join room: { "type": "join", "room": "room-id" }
- Signal message: { "type": "signal", "from": "peer-id", "data": { ... } }

This server is intentionally simple. For production use, add authentication, rate limits, persistence and TLS.


Configuration & Authentication

The relayer supports multiple authentication options (choose one or more):

- API key: set `RELAYER_API_KEY` environment variable. Clients may connect using `ws://host:port?key=VALUE` or using HTTP header `Authorization: Bearer VALUE`.
- JWT: set `RELAYER_JWT_SECRET` environment variable. If set, the relayer will require `Authorization: Bearer <jwt>` and verify tokens with this secret.
- mTLS: set `RELAYER_MTLS_REQUIRED=true` and provide TLS files via `RELAYER_TLS_KEY_PATH`, `RELAYER_TLS_CERT_PATH` and optional `RELAYER_TLS_CA_PATH`. When `RELAYER_MTLS_REQUIRED=true` the relayer requires a client certificate on connect.

Health and Metrics

- `GET /health` returns a simple JSON health object.
- `GET /metrics` exposes Prometheus metrics, including `unit_relayer_ws_connections` and `unit_relayer_ws_messages_total`.

Building native binaries (pkg)

This project includes convenience scripts to build native executables using `pkg`.

Prerequisites:

- Node.js installed (recommended v18+) to run `pkg` locally, or use a CI image with Node.

Build examples:

```bash
cd tools/relayer
npm install
npm run build:linux         # produces dist/unit-relayer-linux
npm run build:linux-arm64   # produces dist/unit-relayer-linux-arm64
npm run build:win           # produces dist/unit-relayer-win.exe
# or build all targets
npm run build:all
```

Notes:

- The produced binaries are standalone and include the JS runtime. Test them in the target environment before production use.
- For production, wrap the binary in a systemd service or container and run behind a reverse proxy with TLS.

Security notes:

- When using mTLS, ensure CA verification and certificate rotation policies are in place; the relayer currently checks presence of a client cert when mTLS is enabled, but you should implement stricter verification (CN, SAN, fingerprint) for production.
- Consider running relayer behind a firewall and enable rate limiting in front of it.

OCSP support

You can enable OCSP checks for client certificates by setting:

- `RELAYER_OCSP_REQUIRED=true`
- `RELAYER_OCSP_ISSUER_CERT_PATH=/path/to/issuer_cert.pem`

The relayer will attempt to query the OCSP responder for the client's cert using the issuer certificate provided. If OCSP check fails or returns non-good status, the connection will be rejected. Ensure the server running relayer can reach the OCSP responder endpoints.

GPG signing, GitHub CI secrets and building `pkg` locally

This project includes a GitHub Actions workflow that can build native binaries using `pkg` and optionally sign them with a GPG key. Below are step-by-step instructions to prepare keys, add secrets to GitHub, and reproduce the local build/sign flow.

1) Generate a GPG key (example, interactive):

```bash
gpg --full-generate-key
```

Choose RSA (default), 3072/4096 bits recommended, set your name/email and passphrase.

2) Export your private key (ASCII armored) for storing as a GitHub secret:

```bash
# replace <KEY_ID> with the output of `gpg --list-secret-keys --keyid-format LONG`
gpg --armor --export-secret-keys <KEY_ID> > relayer_gpg_priv.asc
```

3) Add secrets to your GitHub repository (recommended names):

- `GPG_PRIVATE_KEY` : contents of `relayer_gpg_priv.asc` (the armored private key)
- `GPG_PASSPHRASE`  : the passphrase for the private key (optional; workflow can use it)

You can add secrets via the web UI (Settings → Secrets → Actions) or use the GitHub CLI:

```bash
# requires `gh` CLI authenticated
gh secret set GPG_PRIVATE_KEY --body "$(cat relayer_gpg_priv.asc)"
gh secret set GPG_PASSPHRASE --body "my-passphrase-here"
```

4) Local build & signing with `pkg` (prereqs)

- Install Node.js (LTS), `npm`, `pkg` (globally or via project devDependency), and `gpg`.
- Example on Debian/Ubuntu:

```bash
sudo apt update && sudo apt install -y nodejs npm gnupg
npm install -g pkg
```

5) Reproduce CI locally (recommended): use the helper script included in this repo. From `tools/relayer/` run:

```bash
chmod +x ./scripts/build_release.sh
./scripts/build_release.sh
```

The script will:
- run `npm ci`
- run `npm run build:all` (the `package.json` script that calls `pkg` targets)
- create `dist/` if not present
- generate `dist/CHECKSUMS` (sha256sum of artifacts)
- optionally sign artifacts with GPG (if your private key is available in local gpg keyring or if you set `GPG_PRIVATE_KEY`/`GPG_PASSPHRASE` environment variables and import it temporarily)

6) Notes and tips

- If you prefer not to import the private key into your keyring, you can set `GPG_PRIVATE_KEY` locally and the script will import it into a temporary GNUPGHOME to perform signing.
- CI on GitHub uses the secrets added earlier to import the key for signing during the workflow. Ensure your workflow references `GPG_PRIVATE_KEY` and `GPG_PASSPHRASE` exactly as used in the repo secrets.
- For reproducible builds across platforms, run `pkg` on each target platform or use GitHub Actions matrix builds (workflow already contains a matrix example).

If you want, I can also update the GitHub Actions workflow to include explicit instructions/comments about these secret names and how they are used. Ask and I will patch `.github/workflows/build-relayer.yml`.

Local quick test

There is a helper script to test the relayer locally (installs dependencies, runs server with a test API key, and performs basic health/metrics checks):

```bash
cd tools/relayer
./local_test.sh
```

The script requires `npm` and `node` installed locally.


