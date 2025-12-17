#!/usr/bin/env bash
set -euo pipefail

# Script de teste local para o relayer
# Requisitos: node + npm instalados localmente

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR/tools/relayer"

echo "Instalando dependências (npm ci)..."
npm ci

echo "Iniciando relayer (background) com chaves de teste..."
export RELAYER_API_KEY="testkey"
export RELAYER_JWT_SECRET=""
export RELAYER_MTLS_REQUIRED="false"

node index.js &
PID=$!

echo "Relayer PID: $PID"
echo "Aguardando 1s para inicialização..."
sleep 1

echo "Fazendo health check..."
curl -sS http://localhost:8080/health || true

echo "Mostrando metrics (sample)..."
curl -sS http://localhost:8080/metrics | head -n 20 || true

echo "Conectando via WebSocket de teste (ws client - requires websocat or node)"
echo "Exemplo de conexão: ws://localhost:8080?key=testkey"

echo "Para encerrar o relayer execute: kill $PID"
