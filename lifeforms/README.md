# Lifeforms

## 環境

- Solidity: >=0.6.0 <0.8.0

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

## ローカルデプロイ

```bash
# ターミナル1: ローカルノードを起動
anvil

# ターミナル2: デプロイ
forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

※ 上記の秘密鍵はanvilのデフォルトアカウント(0)です。本番環境では使用しないでください。

## デプロイパラメータ

デプロイスクリプトでは以下のデフォルト値を使用しています：

- name: "Lifeforms"
- symbol: "LIFE"
- maxDuration: 365 days
- price: 0.01 ether

必要に応じて `script/Deploy.s.sol` を編集してください。
