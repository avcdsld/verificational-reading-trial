# 気づいたこと

- transferFrom() / safeTransferFrom() の所有者チェックの require 文がコメントアウトされている。
- 所有者または approved されていない人であれば、transferFrom() / safeTransferFrom() 実行時に OpenTransfer イベントが発行される。
- _checkOpenTransfer() はチェックと名前がついているけど、実際にはイベント発行も行っている。ちょっと関数名が良くない。
- mint には 0.01 ETH が必要。
- 誰でも転送できるが、それでもルールに従う必要がある。from アドレスが実際の所有者でない場合は rever する。ゼロアドレスへの転送は revert する（burn はできない）。
- mint 収益は Internet Archive の公式寄付アドレスに送金される
