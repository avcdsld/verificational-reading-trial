// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

interface ILifeforms2 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function tokenURI(uint256 tokenId) external view returns (string memory);
    function approve(address to, uint256 tokenId) external;
    function getApproved(uint256 tokenId) external view returns (address);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function birth(address to, uint256 tokenId) external payable;
    function safeBirth(address to, uint256 tokenId) external payable;
    function ownerBirth(address to, uint256 tokenId) external;
    function isDead(uint256 tokenId) external view returns (bool);
    function isAlive(uint256 tokenId) external view returns (bool);
    function gravediggerCleanup(uint256 tokenId) external;
    function tokenBirth(uint256 tokenId) external view returns (uint256);
    function tokenOwnerBeginning(uint256 tokenId) external view returns (uint256);
    function getSeed(uint256 tokenId) external view returns (bytes32);
    function getLifeform(uint256 tokenId) external view returns (string memory, address, uint256, uint256, bytes32);
    function baseURI() external view returns (string memory);
    function contractURI() external view returns (string memory);

    function owner() external view returns (address);
    function setPrice(uint256 price_) external;
    function setGravedigger(address gravedigger_) external;
    function setDuration(uint256 duration_) external;
    function setBaseURI(string calldata baseURI_) external;
    function setContractURI(string calldata contractURI_) external;
    function setIsOpen(bool isOpen_) external;
    function withdraw() external;
    function transferOwnership(address newOwner) external;
    function renounceOwnership() external;

    function maxDuration() external view returns (uint256);
    function price() external view returns (uint256);
    function isOpen() external view returns (bool);
    function gravedigger() external view returns (address);

    function executeMetaTransaction(
        address userAddress,
        bytes memory functionSignature,
        bytes32 sigR,
        bytes32 sigS,
        uint8 sigV
    ) external payable returns (bytes memory);
    function getNonce(address user) external view returns (uint256);
    function getChainId() external pure returns (uint256);
    function getDomainSeperator() external view returns (bytes32);

    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

contract Lifeforms2Test is Test {
    ILifeforms2 lf;

    address alice;
    uint256 alicePk;
    address bob = makeAddr("bob");
    address gravediggerAddr = makeAddr("gravedigger");

    uint256 constant PRICE = 0.01 ether;
    uint256 constant MAX_DURATION = 365 days;

    function setUp() public {
        (alice, alicePk) = makeAddrAndKey("alice");

        bytes memory bytecode = abi.encodePacked(
            vm.getCode("Lifeforms2.sol:Lifeforms2"),
            abi.encode("Lifeforms", "LIFE", MAX_DURATION, PRICE)
        );
        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(deployed != address(0), "Deploy failed");
        lf = ILifeforms2(deployed);

        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function _ownerMint(address to, uint256 tokenId) internal {
        lf.ownerBirth(to, tokenId);
    }

    // ================================================================
    // 1. メタトランザクション — なんのために？
    // ================================================================
    // NativeMetaTransaction は Polygon でのガスレス取引を実現する仕組み。
    // ユーザーは署名だけ行い、リレイヤーがガスを負担して代行する。
    // OpenSea on Polygon でのガスレス出品・転送に使われる。

    // ガスレス転送が正しく動作することを確認する。
    // Polygon 上での UX の根幹であり、署名検証やナンス管理が壊れると資産が動かせなくなる。
    function test_MetaTransaction_GaslessTransfer() public {
        _ownerMint(alice, 1);

        // alice が bob への転送を署名し、リレイヤー(this)が送信する
        bytes memory functionSignature = abi.encodeWithSelector(
            ILifeforms2.transferFrom.selector,
            alice, bob, uint256(1)
        );

        // EIP712 ダイジェストを構築
        uint256 nonce = lf.getNonce(alice);
        bytes32 metaTxHash = keccak256(abi.encode(
            keccak256("MetaTransaction(uint256 nonce,address from,bytes functionSignature)"),
            nonce,
            alice,
            keccak256(functionSignature)
        ));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            lf.getDomainSeperator(),
            metaTxHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

        // リレイヤーが代行実行 — alice はガスを払わない
        lf.executeMetaTransaction(alice, functionSignature, r, s, v);

        assertEq(lf.ownerOf(1), bob);
        assertEq(lf.getNonce(alice), 1);
    }

    // ================================================================
    // 2. isDead() と isAlive() — 単純な否定ではない
    // ================================================================
    // 存在しないトークンは isDead=false かつ isAlive=false。
    // 「生きている」「死んでいる」「存在しない」の3状態がある。

    // IMPORTANT: 作品のコアである生命体の生存に関わるステータスなので
    // 「未誕生」「生存」「死亡」の3状態が正しく区別されることを確認する。
    // isDead と isAlive が単純な否定関係でないため、両方を組み合わせた判定ロジックの正しさが重要。
    function test_IsDeadAndIsAlive_ThreeStates() public {
        // 状態1: まだ生まれていない — 存在しない
        assertFalse(lf.isDead(999), "unborn: isDead should be false");
        assertFalse(lf.isAlive(999), "unborn: isAlive should be false");

        // 状態2: 生まれたばかり — 生きている
        _ownerMint(alice, 1);
        assertFalse(lf.isDead(1), "newborn: isDead should be false");
        assertTrue(lf.isAlive(1), "newborn: isAlive should be true");

        // 状態3: 寿命が尽きた — 死んでいる
        vm.warp(block.timestamp + MAX_DURATION + 1);
        assertTrue(lf.isDead(1), "expired: isDead should be true");
        assertFalse(lf.isAlive(1), "expired: isAlive should be false");
    }

    // 寿命の境界値（ちょうど maxDuration vs +1秒）で生死判定が正しく切り替わることを確認する。
    // off-by-one で寿命が1秒ずれるとトークンの生存期間に影響する。
    function test_IsDeadAndIsAlive_BoundaryExact() public {
        _ownerMint(alice, 1);
        uint256 birthTime = block.timestamp;

        // ちょうど maxDuration 経過 — まだ生きている (> であり >= ではない)
        vm.warp(birthTime + MAX_DURATION);
        assertFalse(lf.isDead(1), "at exact duration: still alive");
        assertTrue(lf.isAlive(1));

        // 1秒超過 — 死亡
        vm.warp(birthTime + MAX_DURATION + 1);
        assertTrue(lf.isDead(1), "one second over: dead");
        assertFalse(lf.isAlive(1));
    }

    // ================================================================
    // 3. birth() — mint ではなく "誕生"
    // ================================================================
    // tokenId はユーザーが自由に指定する（auto-increment ではない）。
    // birth = 有料+公開, safeBirth = 有料+公開+受取先チェック, ownerBirth = 無料+owner限定

    // 公開ミントに必要な前提条件（isOpen=true、十分な支払い）が正しく強制されることを確認する。
    // これが壊れると無料ミントや非公開時のミントが可能になり、経済モデルが崩壊する。
    function test_Birth_RequiresPaymentAndOpen() public {
        // isOpen=false では birth できない
        vm.prank(alice);
        vm.expectRevert("Not currently open to the public");
        lf.birth{value: PRICE}(alice, 1);

        lf.setIsOpen(true);

        // 代金不足
        vm.prank(alice);
        vm.expectRevert("Insufficient funds");
        lf.birth{value: PRICE - 1}(alice, 1);

        // 正常な birth
        vm.prank(alice);
        lf.birth{value: PRICE}(alice, 1);
        assertTrue(lf.isAlive(1));
        assertEq(lf.ownerOf(1), alice);
    }

    // safeBirth も birth と同じ支払い・公開条件を要求することを確認する。
    // 片方だけチェックが漏れていると迂回手段になる。
    function test_SafeBirth_AlsoRequiresPaymentAndOpen() public {
        lf.setIsOpen(true);

        vm.prank(alice);
        lf.safeBirth{value: PRICE}(alice, 2);
        assertTrue(lf.isAlive(2));
        assertEq(lf.ownerOf(2), alice);
    }

    // 誕生時にタイムスタンプと seed（ブロックハッシュ由来）が記録されることを確認する。
    // これらは寿命計算とオンチェーン生成アートの根拠となるデータ。
    function test_Birth_RecordsBirthTimestampAndSeed() public {
        _ownerMint(alice, 1);

        assertEq(lf.tokenBirth(1), block.timestamp);
        assertEq(lf.tokenOwnerBeginning(1), block.timestamp);

        bytes32 seed = lf.getSeed(1);
        assertTrue(seed != bytes32(0), "seed should be set at birth");
    }

    // owner は isOpen や支払いに関係なくミントできることを確認する。
    // エアドロップや初期配布のために owner が常にミント可能であることが運用上必要。
    function test_OwnerBirth_FreeAndIgnoresIsOpen() public {
        // isOpen が false でも owner は無料でミントできる
        assertFalse(lf.isOpen());
        _ownerMint(alice, 42);
        assertTrue(lf.isAlive(42));
    }

    // ================================================================
    // 4. gravediggerCleanup() — 墓掘り人
    // ================================================================
    // 死んだトークンを burn する専用ロール。
    // 生きているトークンには手を出せない。owner とも別の権限。

    // gravedigger は死亡トークンのみ burn でき、生存トークンには触れないことを確認する。
    // 生存トークンが burn されるとユーザー資産の不正消失になる。
    function test_Gravedigger_CanOnlyCleanupDeadTokens() public {
        _ownerMint(alice, 1);
        lf.setGravedigger(gravediggerAddr);

        // 生きているトークンは cleanup できない
        vm.prank(gravediggerAddr);
        vm.expectRevert("Can only clean up dead lifeforms");
        lf.gravediggerCleanup(1);

        // 時間経過で死亡
        vm.warp(block.timestamp + MAX_DURATION + 1);
        assertTrue(lf.isDead(1));

        // gravedigger が burn
        vm.prank(gravediggerAddr);
        lf.gravediggerCleanup(1);

        // burn 後は「存在しない」状態に戻る
        assertFalse(lf.isAlive(1));
        assertFalse(lf.isDead(1));
    }

    // IMPORTANT: 重要な役割のように思える。実際の運用も気になる。
    // gravedigger ロールを持たないアドレス（owner 含む）は cleanup できないことを確認する。
    // 権限分離が正しく機能しないと、想定外のアクターがトークンを消せてしまう。
    function test_Gravedigger_OnlyDesignatedAddress() public {
        _ownerMint(alice, 1);
        vm.warp(block.timestamp + MAX_DURATION + 1);

        // gravedigger 未設定なら誰も cleanup できない
        vm.prank(alice);
        vm.expectRevert("Must be gravedigger");
        lf.gravediggerCleanup(1);

        // owner であっても gravedigger でなければ不可
        vm.expectRevert("Must be gravedigger");
        lf.gravediggerCleanup(1);
    }

    // ================================================================
    // 5. メタデータ — 死んだトークンはどうなる？
    // ================================================================

    // 生存中は正しい URI を返し、死亡後は空文字を返すことを確認する。
    // マーケットプレイスでの表示に直結し、死亡トークンが「見えなくなる」という設計意図の検証。
    function test_Metadata_AliveVsDead() public {
        lf.setBaseURI("https://example.com/api/");
        _ownerMint(alice, 42);

        // 生きている間は URI が返る
        assertEq(lf.tokenURI(42), "https://example.com/api/42");

        // 死亡後は空文字
        vm.warp(block.timestamp + MAX_DURATION + 1);
        assertEq(lf.tokenURI(42), "");
    }

    // getLifeform が生存時は全情報を返し、死亡時は全てゼロ値を返すことを確認する。
    // フロントエンドがこの関数に依存する場合、死亡判定のハンドリングが正しい必要がある。
    function test_Metadata_GetLifeform_AliveVsDead() public {
        lf.setBaseURI("https://example.com/api/");
        _ownerMint(alice, 1);

        (string memory uri, address tokenOwner, uint256 birthTs, uint256 ownerBegin, bytes32 seed) = lf.getLifeform(1);
        assertEq(uri, "https://example.com/api/1");
        assertEq(tokenOwner, alice);
        assertEq(birthTs, block.timestamp);
        assertEq(ownerBegin, block.timestamp);
        assertTrue(seed != bytes32(0));

        // 死亡後は全てゼロ値
        vm.warp(block.timestamp + MAX_DURATION + 1);
        (uri, tokenOwner, birthTs, ownerBegin, seed) = lf.getLifeform(1);
        assertEq(uri, "");
        assertEq(tokenOwner, address(0));
        assertEq(birthTs, 0);
        assertEq(ownerBegin, 0);
        assertEq(seed, bytes32(0));
    }

    // コレクション全体のメタデータ URI を設定・取得できることを確認する。
    // OpenSea などがコレクション情報を表示するために使用する。
    function test_Metadata_ContractURI() public {
        assertEq(lf.contractURI(), "");
        lf.setContractURI("https://example.com/contract-metadata.json");
        assertEq(lf.contractURI(), "https://example.com/contract-metadata.json");
    }

    // ================================================================
    // 6. 寿命 (maxDuration) — 実際の値と挙動
    // ================================================================
    // デプロイスクリプトでは 365 days。転送するとタイマーがリセットされ延命される。
    // つまり「転送し続ける限り生き続ける NFT」。

    // デプロイ時のデフォルト値（365日、0.01 ether）が意図通りであることを確認する。
    // コンストラクタ引数の受け渡しミスを検出する。
    function test_Duration_DeployDefault() public {
        assertEq(lf.maxDuration(), 365 days);
        assertEq(lf.price(), 0.01 ether);
    }

    // IMPORTANT: 生命体が生きていることの証がどのように考えられているかの設計
    // 転送によって寿命タイマーがリセットされ、延命されることを確認する。
    // このコントラクトの中核メカニズム — 「人から人へ渡り続ける限り生きる」の検証。
    function test_Duration_TransferResetsTimer() public {
        _ownerMint(alice, 1);

        // 300日経過 — まだ生きている
        vm.warp(block.timestamp + 300 days);
        assertTrue(lf.isAlive(1));

        // alice → bob に転送 → タイマーリセット
        vm.prank(alice);
        lf.transferFrom(alice, bob, 1);
        assertEq(lf.tokenOwnerBeginning(1), block.timestamp);

        // 転送から300日 — まだ生きている
        vm.warp(block.timestamp + 300 days);
        assertTrue(lf.isAlive(1));

        // 転送から366日 — 死亡
        vm.warp(block.timestamp + 66 days);
        assertTrue(lf.isDead(1));
    }

    // IMPORTANT: 生命体が生きていることの証がどのように考えられているかの設計
    // 自分自身への転送ではタイマーがリセットされないことを確認する。
    // これが無ければ自己転送で無限に延命でき、寿命メカニズムが無意味になる。
    function test_Duration_SelfTransferDoesNotResetTimer() public {
        _ownerMint(alice, 1);
        uint256 originalBeginning = lf.tokenOwnerBeginning(1);

        vm.warp(block.timestamp + 100 days);

        // 自分自身への転送ではタイマーはリセットされない
        vm.prank(alice);
        lf.transferFrom(alice, alice, 1);
        assertEq(lf.tokenOwnerBeginning(1), originalBeginning);
    }

    // owner が maxDuration を変更でき、変更後の値が新規トークンに適用されることを確認する。
    // 運用中のパラメータ調整が正しく反映されるかの検証。
    function test_Duration_OwnerCanChange() public {
        lf.setDuration(30 days);
        assertEq(lf.maxDuration(), 30 days);

        _ownerMint(alice, 1);
        vm.warp(block.timestamp + 31 days);
        assertTrue(lf.isDead(1));
    }

    // ================================================================
    // 7. 作者 (owner) の権限
    // ================================================================

    // owner が持つ全設定変更権限が正しく動作することを確認する。
    // 各 setter が独立して機能し、状態が正しく更新されることの網羅的検証。
    function test_OwnerPrivileges_AllSetters() public {
        assertEq(lf.owner(), address(this));

        lf.setPrice(0.05 ether);
        assertEq(lf.price(), 0.05 ether);

        lf.setGravedigger(gravediggerAddr);
        assertEq(lf.gravedigger(), gravediggerAddr);

        lf.setDuration(7 days);
        assertEq(lf.maxDuration(), 7 days);

        lf.setBaseURI("https://new.example.com/");
        assertEq(lf.baseURI(), "https://new.example.com/");

        lf.setContractURI("https://contract.json");
        assertEq(lf.contractURI(), "https://contract.json");

        lf.setIsOpen(true);
        assertTrue(lf.isOpen());

        // 無料ミント権限
        _ownerMint(alice, 1);
        assertTrue(lf.isAlive(1));
    }

    // owner がコントラクトに蓄積された ETH を引き出せることを確認する。
    // 収益回収手段が壊れると資金がロックされる。
    function test_OwnerPrivileges_Withdraw() public {
        lf.setIsOpen(true);

        vm.prank(alice);
        lf.birth{value: PRICE}(alice, 1);
        assertEq(address(lf).balance, PRICE);

        uint256 balanceBefore = address(this).balance;
        lf.withdraw();
        assertEq(address(this).balance, balanceBefore + PRICE);
    }

    // owner 以外が管理関数を呼び出せないことを確認する。
    // アクセス制御の欠陥は直接的なセキュリティリスクになる。
    function test_OwnerPrivileges_NonOwnerCantCall() public {
        vm.startPrank(alice);

        vm.expectRevert("Ownable: caller is not the owner");
        lf.setPrice(0);

        vm.expectRevert("Ownable: caller is not the owner");
        lf.setGravedigger(alice);

        vm.expectRevert("Ownable: caller is not the owner");
        lf.setDuration(0);

        vm.expectRevert("Ownable: caller is not the owner");
        lf.setIsOpen(true);

        vm.expectRevert("Ownable: caller is not the owner");
        lf.ownerBirth(alice, 99);

        vm.expectRevert("Ownable: caller is not the owner");
        lf.withdraw();

        vm.stopPrank();
    }

    // ================================================================
    // 8. 生き残りカウント — balanceOf は生存者のみ数える
    // ================================================================

    // balanceOf が生存トークンのみをカウントし、死亡トークンを除外することを確認する。
    // ウォレットやマーケットプレイスの表示に影響し、死亡トークンが「消える」UX の正しさに関わる。
    function test_BalanceOf_OnlyCountsAlive() public {
        _ownerMint(alice, 1);
        _ownerMint(alice, 2);
        _ownerMint(alice, 3);
        assertEq(lf.balanceOf(alice), 3);

        // 全トークンの寿命が尽きる
        vm.warp(block.timestamp + MAX_DURATION + 1);
        assertEq(lf.balanceOf(alice), 0, "dead tokens should not be counted");

        // ownerOf も address(0) を返す
        assertEq(lf.ownerOf(1), address(0));
        assertEq(lf.ownerOf(2), address(0));
        assertEq(lf.ownerOf(3), address(0));
    }

    // ================================================================
    // 9. 最大 mint 数 — 上限はない
    // ================================================================
    // maxSupply のような制限は存在しない。
    // tokenId はユーザーが自由に指定し、任意の uint256 を使える。

    // 供給上限がなく、任意の tokenId でミントできることを確認する。
    // 意図的に上限を設けない設計であることの明示的な文書化。
    function test_NoMaxSupply_ArbitraryTokenIds() public {
        _ownerMint(alice, 0);
        _ownerMint(alice, 1);
        _ownerMint(alice, 100);
        _ownerMint(alice, 999999);
        _ownerMint(bob, type(uint256).max);

        assertTrue(lf.isAlive(0));
        assertTrue(lf.isAlive(1));
        assertTrue(lf.isAlive(100));
        assertTrue(lf.isAlive(999999));
        assertTrue(lf.isAlive(type(uint256).max));

        assertEq(lf.balanceOf(alice), 4);
        assertEq(lf.balanceOf(bob), 1);
    }

    // 同じ tokenId の重複ミントが拒否されることを確認する。
    // 上限がない代わりに、一意性は保証される必要がある。
    function test_NoMaxSupply_DuplicateTokenIdReverts() public {
        _ownerMint(alice, 1);
        vm.expectRevert("ERC721: token already minted");
        _ownerMint(bob, 1);
    }

    // ================================================================
    // おまけ: OpenSea プロキシの自動承認
    // ================================================================

    // OpenSea のプロキシアドレスが全ユーザーに対して自動承認されていることを確認する。
    // Polygon 上での gasless listing を実現するための設定。
    function test_OpenSeaProxyAutoApproved() public {
        address openseaProxy = 0x58807baD0B376efc12F5AD86aAc70E78ed67deaE;

        assertTrue(lf.isApprovedForAll(alice, openseaProxy));
        assertTrue(lf.isApprovedForAll(bob, openseaProxy));
        assertFalse(lf.isApprovedForAll(alice, bob));
    }

    // ================================================================
    // おまけ: ERC165 インターフェース宣言
    // ================================================================

    // ERC165/ERC721/ERC721Metadata/ERC721Enumerable のインターフェースを宣言していることを確認する。
    // マーケットプレイスやウォレットがコントラクトの機能を検出するために必要。
    function test_SupportsInterfaces() public {
        assertTrue(lf.supportsInterface(0x01ffc9a7));  // ERC165
        assertTrue(lf.supportsInterface(0x80ac58cd));  // ERC721
        assertTrue(lf.supportsInterface(0x5b5e139f));  // ERC721Metadata
        assertTrue(lf.supportsInterface(0x780e9d63));  // ERC721Enumerable (登録はあるが関数は未実装)
    }

    receive() external payable {}
}
