# 気づいたこと

- class（1〜4）はビジュアルの色テーマを表す。value = class × 1億 + mass でエンコードされている。
- class はマージ後も変わらない。生存トークンが自身の class を維持し、死亡した側の class は消失する。
- mass の最大値は 99,999,998。99,999,999 はミント時のスキップフラグ（sentinel）として予約されている。
- 全トークンの mass 合計が 99,999,999 未満に制約されているため、マージ時に class 桁への繰り上がりは数学的に起こり得ない。_merge() 内に mass 上限チェックがないのはバグではなく、この設計による保証。
- マージ時には Transfer(owner/to, address(0), deadTokenId) のバーンイベントが emit される（明示的 merge() でも転送時の自動マージでも）。
- 同じ mass のトークンをマージした場合、receiver（第1引数 / 既存トークン）が生存する。_merge 内の `massRcvr >= massSndr` の `>=` による。
- Alpha はシステム内で最大 mass を持つトークン。更新条件は厳密な `>` であり、`>=` ではない。
- NiftyRegistry の権限は mint() と batchSetMergeCountFromSnapshot() のアクセス制御に使用。_registry は immutable。
- batchSetMergeCountFromSnapshot() や sentinel の仕組みは、既存状態からの移行（コントラクトアップグレードまたはオフチェーン状態の取り込み）を示唆している。
- メタデータはオンチェーン SVG 生成で、data:application/json;base64 形式の data URI で返される。
- mergeCount は生存トークンに対してマージのたびに 1 ずつ累積する。

# メインネットでの実態

- メインネットのコントラクトは2つ存在する。オリジナル（0x27d2...）にバグがあり、多くのコレクターが Nifty Gateway から NFT を引き出せなかったため、約7日後に修正版（0xc3f8...）がデプロイされた。このリポジトリのコードは修正版に対応する。
- sentinel は実際に278個使用された。28,990個のIDスロットのうち28,712個が実際にミントされ、278個（約0.96%）が欠番となった。旧コントラクトで既にマージ等で消滅していたトークンIDをスキップし、残りのIDを元の体系と一致させるための仕組み。
- 現在は19,045トークンが生存しており、9,667個がマージやバーンで消滅している。
- 両方のコントラクトとも name() は "merge." を返す。Etherscan で "Merge" と表示されるのは Solidity の contract 識別子であり、ERC721 の name() とは別。
