// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "forge-std/Test.sol";
import "../src/core/Merge.sol";
import "../src/core/MergeMetadata.sol";

contract MockNiftyRegistry {
    mapping(address => bool) public validSenders;

    function setValidSender(address sender, bool valid) external {
        validSenders[sender] = valid;
    }

    function isValidNiftySender(address sending_key) external view returns (bool) {
        return validSenders[sending_key];
    }
}

contract MergeTest is Test {
    Merge public mergeContract;
    MergeMetadata public metadata;
    MockNiftyRegistry public registry;

    address pak;
    address omnibus;
    address alice;
    address bob;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event AlphaMassUpdate(uint256 indexed tokenId, uint256 alphaMass);
    event MassUpdate(uint256 indexed tokenIdBurned, uint256 indexed tokenIdPersist, uint256 mass);

    function setUp() public {
        pak = makeAddr("pak");
        omnibus = makeAddr("omnibus");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        registry = new MockNiftyRegistry();
        metadata = new MergeMetadata();
        mergeContract = new Merge(address(registry), omnibus, address(metadata), pak);

        registry.setValidSender(address(this), true);
    }

    function _mintOne(uint256 class_, uint256 mass) internal returns (uint256 tokenId) {
        tokenId = mergeContract._nextMintId();
        uint256[] memory values = new uint256[](1);
        values[0] = mergeContract.encodeClassAndMass(class_, mass);
        mergeContract.mint(values);
    }

    // ================================================================
    // Q1. Class: encoding, decoding, and preservation across merge
    // ================================================================

    // class 1〜4 それぞれで encode → decode の往復変換が正しく動作することを確認。
    // value = class * 1億 + mass のエンコーディング仕様の検証。
    function test_Q1_classEncodeDecode() public {
        for (uint256 c = 1; c <= 4; c++) {
            uint256 encoded = mergeContract.encodeClassAndMass(c, 42);
            (uint256 decodedClass, uint256 decodedMass) = mergeContract.decodeClassAndMass(encoded);
            assertEq(decodedClass, c);
            assertEq(decodedMass, 42);
        }
    }

    // class が有効範囲 [1, 4] の外（0 や 5）の場合に revert することを確認。
    function test_Q1_classRangeValidation() public {
        vm.expectRevert("Merge: Class must be [1, 4].");
        mergeContract.encodeClassAndMass(0, 1);

        vm.expectRevert("Merge: Class must be [1, 4].");
        mergeContract.encodeClassAndMass(5, 1);
    }

    // 同じ class のトークン同士をマージした場合、生存トークンの class が変わらず mass だけが合算されることを確認。
    function test_Q1_classPreservedAfterMerge_sameClass() public {
        uint256 t1 = _mintOne(2, 1000);
        uint256 t2 = _mintOne(2, 500);

        vm.prank(omnibus);
        mergeContract.merge(t1, t2);

        (uint256 class_, uint256 mass) = mergeContract.decodeClassAndMass(mergeContract.getValueOf(t1));
        assertEq(class_, 2, "class preserved");
        assertEq(mass, 1500, "mass combined");
    }

    // [IMPORTANT] 異なる class のトークン同士をマージした場合、生存トークンが自身の class を維持することを確認。
    // 死亡した側の class は消失する。
    function test_Q1_classPreservedAfterMerge_differentClass() public {
        uint256 t1 = _mintOne(1, 1000); // heavier, survives
        uint256 t2 = _mintOne(3, 500);  // lighter, dies

        vm.prank(omnibus);
        mergeContract.merge(t1, t2);

        (uint256 class_, ) = mergeContract.decodeClassAndMass(mergeContract.getValueOf(t1));
        assertEq(class_, 1, "surviving token keeps its own class");
    }

    // ================================================================
    // Q2. Token supply
    // ================================================================

    // ミントするたびに totalSupply が正しくインクリメントされることを確認。
    function test_Q2_totalSupplyTracked() public {
        assertEq(mergeContract.totalSupply(), 0);
        _mintOne(1, 100);
        assertEq(mergeContract.totalSupply(), 1);
        _mintOne(2, 200);
        _mintOne(3, 300);
        assertEq(mergeContract.totalSupply(), 3);
    }

    // sentinel 値（mass == 99,999,999）がミント時にスキップされることを確認。
    // トークンIDは消費されるが、トークン自体は生成されない。
    function test_Q2_sentinelSkipsMinting() public {
        uint256[] memory values = new uint256[](3);
        values[0] = mergeContract.encodeClassAndMass(1, 100);
        values[1] = 199_999_999; // sentinel for class 1
        values[2] = mergeContract.encodeClassAndMass(2, 200);

        uint256 firstId = mergeContract._nextMintId();
        mergeContract.mint(values);

        assertEq(mergeContract.totalSupply(), 2, "sentinel skipped");
        assertEq(mergeContract._nextMintId(), firstId + 3, "id still increments");
        assertTrue(mergeContract.exists(firstId));
        assertFalse(mergeContract.exists(firstId + 1));
        assertTrue(mergeContract.exists(firstId + 2));
    }

    // マージによってトークンが1つ消滅し、totalSupply が減少することを確認。
    function test_Q2_supplyDecreasesOnMerge() public {
        _mintOne(1, 1000);
        _mintOne(1, 500);
        assertEq(mergeContract.totalSupply(), 2);

        vm.prank(omnibus);
        mergeContract.merge(1, 2);
        assertEq(mergeContract.totalSupply(), 1);
    }

    // finalize() 後にミントが不可能になることを確認。
    function test_Q2_mintBlockedAfterFinalize() public {
        vm.prank(pak);
        mergeContract.finalize();

        uint256[] memory values = new uint256[](1);
        values[0] = mergeContract.encodeClassAndMass(1, 100);
        vm.expectRevert("Merge: Minting is finalized.");
        mergeContract.mint(values);
    }

    // ================================================================
    // Q3. Mass boundaries
    // ================================================================

    // mass の最小値 1 でミントできることを確認。
    function test_Q3_massMinIsOne() public {
        uint256 t = _mintOne(1, 1);
        assertEq(mergeContract.massOf(t), 1);
    }

    // mass の最大値 99,999,998 でミントできることを確認。
    function test_Q3_massMaxIs99999998() public {
        uint256 t = _mintOne(1, 99_999_998);
        assertEq(mergeContract.massOf(t), 99_999_998);
    }

    // mass = 0 はエンコード時に revert することを確認。
    function test_Q3_massZeroReverts() public {
        vm.expectRevert("Merge: Mass must be [1, 100m - 1).");
        mergeContract.encodeClassAndMass(1, 0);
    }

    // mass = 99,999,999 はミント時のスキップフラグ（sentinel）として予約されており、
    // 通常の mass としては無効で revert することを確認。
    function test_Q3_mass99999999IsSentinelAndInvalid() public {
        vm.expectRevert("Merge: Mass must be [1, 100m - 1).");
        mergeContract.encodeClassAndMass(1, 99_999_999);
    }

    // 全トークンの mass 合計が 99,999,999 以上になるミントが revert することを確認。
    // この上限により、マージ時に class 桁への繰り上がりが起きないことが保証される。
    function test_Q3_totalMassOverflow() public {
        _mintOne(1, 50_000_000);

        uint256[] memory values = new uint256[](1);
        values[0] = mergeContract.encodeClassAndMass(1, 50_000_000);
        vm.expectRevert("Merge: Mass total overflow");
        mergeContract.mint(values);
    }

    // 合計 mass が上限ぎりぎり（99,999,998）の場合はミントが成功することを確認。
    function test_Q3_totalMassJustUnderLimit() public {
        _mintOne(1, 49_999_999);
        _mintOne(2, 49_999_999);
        // total = 99,999,998 < 99,999,999
        assertEq(mergeContract.totalSupply(), 2);
    }

    // ================================================================
    // Q4. Burn events on merge
    // ================================================================

    // 明示的な merge() 呼び出し時に、死亡トークンに対して Transfer(owner, address(0), tokenId) が
    // emit されることを確認。ERC721 標準のバーン表現。
    function test_Q4_explicitMergeEmitsBurnTransfer() public {
        uint256 t1 = _mintOne(1, 1000);
        uint256 t2 = _mintOne(1, 500);

        vm.expectEmit(true, true, true, true);
        emit Transfer(omnibus, address(0), t2);

        vm.prank(omnibus);
        mergeContract.merge(t1, t2);
    }

    // [IMPORTANT] 非ホワイトリストアドレスへの転送で自動マージが発生した際にも、
    // 死亡トークンに対するバーンイベント Transfer(to, address(0), tokenId) が emit されることを確認。
    function test_Q4_autoMergeOnTransferEmitsBurn() public {
        uint256 t1 = _mintOne(1, 1000);
        uint256 t2 = _mintOne(1, 500);

        vm.prank(omnibus);
        mergeContract.transferFrom(omnibus, alice, t1);

        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), t2);

        vm.prank(omnibus);
        mergeContract.transferFrom(omnibus, alice, t2);

        assertFalse(mergeContract.exists(t2));
        assertTrue(mergeContract.exists(t1));
    }

    // マージで死亡したトークンのオーナー情報と value が完全に削除され、
    // ownerOf / getValueOf が revert することを確認。
    function test_Q4_burnedTokenFullyDeleted() public {
        uint256 t1 = _mintOne(1, 1000);
        uint256 t2 = _mintOne(1, 500);

        vm.prank(omnibus);
        mergeContract.merge(t1, t2);

        vm.expectRevert("ERC721: nonexistent token");
        mergeContract.ownerOf(t2);

        vm.expectRevert("ERC721: nonexistent token");
        mergeContract.getValueOf(t2);
    }

    // ================================================================
    // Q5. Alpha — the heaviest token
    // ================================================================

    // ミント時に最大 mass のトークンが Alpha として追跡されることを確認。
    // より重いトークンをミントすると Alpha が更新され、軽いトークンでは変わらない。
    function test_Q5_alphaSetDuringMint() public {
        _mintOne(1, 100);
        assertEq(mergeContract._alphaId(), 1);
        assertEq(mergeContract._alphaMass(), 100);

        _mintOne(2, 500); // heavier → new alpha
        assertEq(mergeContract._alphaId(), 2);
        assertEq(mergeContract._alphaMass(), 500);

        _mintOne(1, 50); // lighter → alpha unchanged
        assertEq(mergeContract._alphaId(), 2);
    }

    // マージで合算 mass が現在の Alpha を超えた場合、Alpha が更新されることを確認。
    function test_Q5_alphaUpdatedByMerge() public {
        _mintOne(1, 300);  // token 1
        _mintOne(1, 400);  // token 2 = alpha
        _mintOne(1, 200);  // token 3
        assertEq(mergeContract._alphaId(), 2);

        // Merge 1 + 3 → 500 > 400 → new alpha
        vm.prank(omnibus);
        mergeContract.merge(1, 3);

        assertEq(mergeContract._alphaId(), 1);
        assertEq(mergeContract._alphaMass(), 500);
    }

    // マージで合算 mass が現在の Alpha と同値の場合は Alpha が更新されないことを確認。
    // 比較は厳密な > であり、>= ではない。
    function test_Q5_alphaUnchangedWhenCombinedMassEquals() public {
        _mintOne(1, 500);  // token 1 = alpha
        _mintOne(1, 200);  // token 2
        _mintOne(1, 300);  // token 3

        // Merge 2 + 3 → 500, equals alpha but not greater → no update
        vm.prank(omnibus);
        mergeContract.merge(2, 3);

        assertEq(mergeContract._alphaId(), 1, "alpha unchanged when equal");
    }

    // ================================================================
    // Q6. NiftyRegistry access control
    // ================================================================

    // NiftyRegistry に登録された有効な sender がミントできることを確認。
    function test_Q6_validSenderCanMint() public {
        _mintOne(1, 100);
        assertEq(mergeContract.totalSupply(), 1);
    }

    // NiftyRegistry に未登録のアドレスがミントしようとすると revert することを確認。
    function test_Q6_invalidSenderCannotMint() public {
        uint256[] memory values = new uint256[](1);
        values[0] = mergeContract.encodeClassAndMass(1, 100);

        vm.prank(alice);
        vm.expectRevert("Merge: Invalid msg.sender");
        mergeContract.mint(values);
    }

    // NiftyRegistry に未登録のアドレスが batchSetMergeCountFromSnapshot を呼ぶと revert することを確認。
    function test_Q6_invalidSenderCannotBatchSetMergeCount() public {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        vm.prank(alice);
        vm.expectRevert("Merge: Invalid msg.sender");
        mergeContract.batchSetMergeCountFromSnapshot(ids, counts);
    }

    // _registry がコンストラクタで設定された immutable な値であることを確認。
    function test_Q6_registryImmutable() public {
        assertEq(mergeContract._registry(), address(registry));
    }

    // ================================================================
    // Q7. Metadata
    // ================================================================

    // tokenURI が "data:application/json;base64," プレフィックスの data URI 形式で返されることを確認。
    // メタデータはオンチェーン SVG を含む JSON が base64 エンコードされている。
    function test_Q7_tokenURIReturnsBase64DataUri() public {
        _mintOne(1, 1000);
        string memory uri = mergeContract.tokenURI(1);

        bytes memory uriBytes = bytes(uri);
        bytes memory prefix = "data:application/json;base64,";
        for (uint256 i = 0; i < prefix.length; i++) {
            assertEq(uint8(uriBytes[i]), uint8(prefix[i]));
        }
    }

    // 存在しないトークンの tokenURI を取得しようとすると revert することを確認。
    function test_Q7_nonexistentTokenReverts() public {
        vm.expectRevert("ERC721: nonexistent token");
        mergeContract.tokenURI(999);
    }

    // ================================================================
    // Q8. Equal mass merge — which token survives?
    // ================================================================

    // [IMPORTANT] 同じ mass の明示的マージでは、第1引数（receiver）が生存し第2引数（sender）が死亡することを確認。
    // _merge 内の `massRcvr >= massSndr` 比較で等値は receiver 勝ちとなる。
    function test_Q8_equalMass_explicitMerge_receiverSurvives() public {
        uint256 t1 = _mintOne(1, 1000);
        uint256 t2 = _mintOne(2, 1000);

        vm.prank(omnibus);
        uint256 dead = mergeContract.merge(t1, t2);

        assertEq(dead, t2, "sender (2nd arg) dies when equal mass");
        assertTrue(mergeContract.exists(t1));
        assertFalse(mergeContract.exists(t2));
        assertEq(mergeContract.massOf(t1), 2000);
    }

    // [IMPORTANT] 転送による自動マージで mass が同じ場合、既存トークンが生存し送られたトークンが死亡することを確認。
    // _merge(current, sent) の呼び出しで current が receiver となるため。
    function test_Q8_equalMass_autoMerge_existingTokenSurvives() public {
        uint256 t1 = _mintOne(1, 1000);
        uint256 t2 = _mintOne(2, 1000);

        vm.prank(omnibus);
        mergeContract.transferFrom(omnibus, alice, t1);

        vm.prank(omnibus);
        mergeContract.transferFrom(omnibus, alice, t2);

        assertTrue(mergeContract.exists(t1), "existing token survives");
        assertFalse(mergeContract.exists(t2), "incoming token dies");
        assertEq(mergeContract.massOf(t1), 2000);
    }

    // mass が異なる場合、引数の順序に関係なく重い方が生存することを確認。
    function test_Q8_unequalMass_heavierAlwaysSurvives() public {
        uint256 t1 = _mintOne(1, 500);  // lighter
        uint256 t2 = _mintOne(1, 1000); // heavier

        vm.prank(omnibus);
        uint256 dead = mergeContract.merge(t1, t2);

        assertEq(dead, t1, "lighter dies regardless of arg order");
        assertTrue(mergeContract.exists(t2));
        assertEq(mergeContract.massOf(t2), 1500);
    }

    // ================================================================
    // Q9. Custom events
    // ================================================================

    // ミント時に Alpha が更新された場合、AlphaMassUpdate(tokenId, mass) が emit されることを確認。
    function test_Q9_AlphaMassUpdate_onMint() public {
        vm.expectEmit(true, false, false, true);
        emit AlphaMassUpdate(1, 100);
        _mintOne(1, 100);
    }

    // マージで Alpha が入れ替わった場合、AlphaMassUpdate が emit されることを確認。
    function test_Q9_AlphaMassUpdate_onMerge() public {
        _mintOne(1, 300);
        _mintOne(1, 400); // alpha
        _mintOne(1, 200);

        vm.expectEmit(true, false, false, true);
        emit AlphaMassUpdate(1, 500);

        vm.prank(omnibus);
        mergeContract.merge(1, 3);
    }

    // マージ時に MassUpdate(burnedId, survivorId, combinedMass) が emit されることを確認。
    // 死亡トークンと生存トークンの ID、および合算後の mass が記録される。
    function test_Q9_MassUpdate_onMerge() public {
        _mintOne(1, 1000);
        _mintOne(1, 500);

        vm.expectEmit(true, true, false, true);
        emit MassUpdate(2, 1, 1500);

        vm.prank(omnibus);
        mergeContract.merge(1, 2);
    }

    // burn() 時に MassUpdate(tokenId, 0, 0) が emit されることを確認。
    // persistId=0, mass=0 でバーンを表現する。
    function test_Q9_MassUpdate_onBurn() public {
        _mintOne(1, 1000);

        vm.expectEmit(true, true, false, true);
        emit MassUpdate(1, 0, 0);

        vm.prank(omnibus);
        mergeContract.burn(1);
    }

    // ================================================================
    // Supplementary: mergeCount, freeze
    // ================================================================

    // [IMPORTANT] マージのたびに生存トークンの mergeCount が 1 ずつ増加することを確認。
    function test_mergeCountIncremented() public {
        uint256 t1 = _mintOne(1, 1000);
        uint256 t2 = _mintOne(1, 500);
        uint256 t3 = _mintOne(1, 300);

        assertEq(mergeContract.getMergeCount(t1), 0);

        vm.prank(omnibus);
        mergeContract.merge(t1, t2);
        assertEq(mergeContract.getMergeCount(t1), 1);

        vm.prank(omnibus);
        mergeContract.merge(t1, t3);
        assertEq(mergeContract.getMergeCount(t1), 2);
    }

    // freeze 状態では transferFrom と merge の両方が revert することを確認。
    function test_frozenBlocksTransferAndMerge() public {
        _mintOne(1, 1000);
        _mintOne(1, 500);

        vm.prank(pak);
        mergeContract.freeze();

        vm.prank(omnibus);
        vm.expectRevert("Merge: movement frozen");
        mergeContract.transferFrom(omnibus, alice, 1);

        vm.prank(omnibus);
        vm.expectRevert("Merge: movement frozen");
        mergeContract.merge(1, 2);
    }
}
