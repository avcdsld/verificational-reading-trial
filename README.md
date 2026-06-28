# Verificational Reading

「コード作品の検証的読解」プロジェクトのためのリポジトリです。

スマートコントラクト作品を対象に、テストコードを作成していただきます。作業手順の詳細は別途お伝えした資料を参照してください。

## 作品一覧

### 共通課題: OpenTransfer

全協力者に共通で取り組んでいただく作品です。

- ディレクトリ: `open-transfer/`
- Solidity: 0.8.6
- OpenZeppelin Contracts: v4.3.0

### 割当課題A: merge.

協力者に個別に割り当てられる作品です。

- ディレクトリ: `merge/`
- Solidity: ^0.8.6

### 割当課題B: Lifeforms

協力者に個別に割り当てられる作品です。

- ディレクトリ: `lifeforms/`
- Solidity: 0.8.6

## セットアップ

各プロジェクトは [Foundry](https://book.getfoundry.sh/) を使用していますが、`src/` 内のコードを使って、Hardhat など別のフレームワークでテストを構築しても構いません。

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

各ディレクトリに移動してビルド・テストを実行できます。

```bash
cd open-transfer  # または merge, lifeforms
forge build
forge test
```