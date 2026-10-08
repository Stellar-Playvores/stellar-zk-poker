#!/usr/bin/env bash
set -euo pipefail

# Stellar ZK Poker - Deploy Script
# Deploys contracts to Soroban testnet and starts services

NETWORK="${NETWORK:-testnet}"
SOROBAN_RPC="${SOROBAN_RPC:-https://soroban-testnet.stellar.org}"
SOROBAN_NETWORK_PASSPHRASE="${SOROBAN_NETWORK_PASSPHRASE:-Test SDF Network ; September 2015}"

echo "=== Stellar ZK Poker Deploy ==="
echo "Network: $NETWORK"
echo "RPC: $SOROBAN_RPC"
echo ""

# Check dependencies
command -v stellar >/dev/null 2>&1 || { echo "stellar CLI not found. Install: cargo install stellar-cli"; exit 1; }

# --- Step 1: Build Soroban contracts ---
echo "=== Building Soroban contracts ==="
cargo build --release --target wasm32-unknown-unknown \
  -p stellar-zk-poker-table \
  -p stellar-zk-poker-zk-verifier \
  -p stellar-zk-poker-committee-registry

echo "Optimizing WASM..."
for contract in stellar_zk_poker_table stellar_zk_poker_zk_verifier stellar_zk_poker_committee_registry; do
  stellar contract optimize \
    --wasm "target/wasm32-unknown-unknown/release/${contract}.wasm" 2>/dev/null || true
done

# --- Step 2: Compile Noir circuits ---
echo ""
echo "=== Compiling Noir circuits ==="
./scripts/compile-circuits.sh

# --- Step 3: Generate deployer identity ---
echo ""
echo "=== Setting up deployer identity ==="
if ! stellar keys show deployer >/dev/null 2>&1; then
  stellar keys generate deployer --network "$NETWORK"
  echo "Funding deployer account..."
  stellar keys fund deployer --network "$NETWORK" || true
fi

DEPLOYER=$(stellar keys address deployer)
echo "Deployer: $DEPLOYER"

# --- Step 4: Deploy contracts ---
echo ""
echo "=== Deploying contracts ==="

echo "Deploying stellar-zk-poker-zk-verifier..."
STELLAR_ZK_POKER_ZK_VERIFIER_ID=$(stellar contract deploy \
  --wasm target/wasm32-unknown-unknown/release/stellar_zk_poker_zk_verifier.wasm \
  --source deployer \
  --network "$NETWORK" 2>/dev/null)
echo "  ZK Verifier: $STELLAR_ZK_POKER_ZK_VERIFIER_ID"

echo "Deploying stellar-zk-poker-committee-registry..."
STELLAR_ZK_POKER_COMMITTEE_ID=$(stellar contract deploy \
  --wasm target/wasm32-unknown-unknown/release/stellar_zk_poker_committee_registry.wasm \
  --source deployer \
  --network "$NETWORK" 2>/dev/null)
echo "  Committee Registry: $STELLAR_ZK_POKER_COMMITTEE_ID"

echo "Deploying stellar-zk-poker-table..."
STELLAR_ZK_POKER_TABLE_ID=$(stellar contract deploy \
  --wasm target/wasm32-unknown-unknown/release/stellar_zk_poker_table.wasm \
  --source deployer \
  --network "$NETWORK" 2>/dev/null)
echo "  Poker Table: $STELLAR_ZK_POKER_TABLE_ID"

# --- Step 5: Initialize contracts ---
echo ""
echo "=== Initializing contracts ==="

stellar contract invoke \
  --id "$STELLAR_ZK_POKER_ZK_VERIFIER_ID" \
  --source deployer \
  --network "$NETWORK" \
  -- initialize --admin "$DEPLOYER" 2>/dev/null

stellar contract invoke \
  --id "$STELLAR_ZK_POKER_COMMITTEE_ID" \
  --source deployer \
  --network "$NETWORK" \
  -- initialize --admin "$DEPLOYER" 2>/dev/null

echo ""
echo "=== Deploy Complete ==="
echo ""
echo "Contract Addresses:"
echo "  ZK_VERIFIER=$STELLAR_ZK_POKER_ZK_VERIFIER_ID"
echo "  COMMITTEE_REGISTRY=$STELLAR_ZK_POKER_COMMITTEE_ID"
echo "  POKER_TABLE=$STELLAR_ZK_POKER_TABLE_ID"
echo ""
echo "Next steps:"
echo "  1. Set verification keys: stellar contract invoke --id $STELLAR_ZK_POKER_ZK_VERIFIER_ID -- set_verification_key ..."
echo "  2. Register committee members: stellar contract invoke --id $STELLAR_ZK_POKER_COMMITTEE_ID -- register_member ..."
echo "  3. Start MPC nodes: docker-compose up stellar-zk-poker-node-0 stellar-zk-poker-node-1 stellar-zk-poker-node-2"
echo "  4. Start coordinator: docker-compose up stellar-zk-poker-coordinator"
echo "  5. Start web app: cd app && npm run dev"
