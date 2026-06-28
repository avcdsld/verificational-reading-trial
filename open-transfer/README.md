# OpenTransfer

## 環境

- Solidity: 0.8.6
- OpenZeppelin Contracts: v4.3.0

## セットアップ

Foundryをインストールしてください。

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## ビルド

```bash
forge build
```

## テスト

```bash
# 通常のテスト（フォークテストを除外）
forge test --no-match-path test/OpenTransfer.fork.t.sol

# 詳細出力付き
forge test --no-match-path test/OpenTransfer.fork.t.sol -vvv

# Ethereum mainnet をフォークしてテスト（owner() 関数のテスト用）
forge test --match-path test/OpenTransfer.fork.t.sol --fork-url https://ethereum-rpc.publicnode.com -vvv
```

## ローカルデプロイ

```bash
# ターミナル1: ローカルノードを起動
anvil

# ターミナル2: デプロイ
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

※ 上記の秘密鍵はanvilのデフォルトアカウント(0)です。本番環境では使用しないでください。
