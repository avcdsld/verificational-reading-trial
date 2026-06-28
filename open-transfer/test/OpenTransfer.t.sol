// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "forge-std/Test.sol";
import {OpenTransfer as OpenTransferNFT} from "../src/OpenTransfer.sol";

contract OpenTransferTest is Test {
    OpenTransferNFT public nft;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    event OpenTransfer(address indexed by, address indexed from, address indexed to, uint256 tokenId);
    event Mint(address indexed buyer, uint256 indexed tokenId);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    function setUp() public {
        nft = new OpenTransferNFT();
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    // ============ Constructor Tests ============

    // 重要である理由: 名は体を表すため
    // コントラクトの名前が "OpenTransfer" であることを確認
    function test_Constructor_Name() public {
        assertEq(nft.name(), "OpenTransfer");
    }

    // コメントアウトした理由: 慣習に従っており、特に意味はないかなと思われる
    // // コントラクトのシンボルが "OT" であることを確認
    // function test_Constructor_Symbol() public {
    //     assertEq(nft.symbol(), "OT");
    // }

    // コメントアウトした理由: 残高の状態は特に重要でない気がする
    // // 初期状態で totalSupply が 0 であることを確認
    // function test_Constructor_TotalSupply() public {
    //     assertEq(nft.totalSupply(), 0);
    // }

    // ============ Mint Tests ============

    // // 1個のNFTを正常にミントできることを確認
    // function test_Mint_Single() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);

    //     assertEq(nft.totalSupply(), 1);
    //     assertEq(nft.ownerOf(0), alice);
    //     assertEq(nft.balanceOf(alice), 1);
    // }

    // // 複数のNFTを一度にミントできることを確認
    // function test_Mint_Multiple() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.05 ether}(5);

    //     assertEq(nft.totalSupply(), 5);
    //     assertEq(nft.balanceOf(alice), 5);
    //     for (uint256 i = 0; i < 5; i++) {
    //         assertEq(nft.ownerOf(i), alice);
    //     }
    // }

    // // ミント時に Mint イベントが発行されることを確認
    // function test_Mint_EmitsMintEvent() public {
    //     vm.prank(alice);
    //     vm.expectEmit(true, true, false, true);
    //     emit Mint(alice, 0);
    //     nft.mint{value: 0.01 ether}(1);
    // }

    // // 最大供給量(100個)までミントできることを確認
    // function test_Mint_MaxSupply() public {
    //     vm.prank(alice);
    //     nft.mint{value: 1 ether}(100);

    //     assertEq(nft.totalSupply(), 100);
    // }

    // 重要である理由: 100という上限に何か意味があるような気がする
    // 最大供給量を超えるミントはリバートすることを確認
    function test_Mint_RevertWhen_ExceedsMaxSupply() public {
        vm.prank(alice);
        vm.expectRevert("OpenTransfer: Invalid quantity");
        nft.mint{value: 1.01 ether}(101);
    }

    // // 既存のミント後に最大供給量を超えるミントはリバートすることを確認
    // function test_Mint_RevertWhen_ExceedsMaxSupplyAfterPartialMint() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.5 ether}(50);

    //     vm.prank(bob);
    //     vm.expectRevert("OpenTransfer: Invalid quantity");
    //     nft.mint{value: 0.51 ether}(51);
    // }

    // // 送金額が不足している場合はリバートすることを確認
    // function test_Mint_RevertWhen_InvalidValue_TooLow() public {
    //     vm.prank(alice);
    //     vm.expectRevert("OpenTransfer: Invalid value");
    //     nft.mint{value: 0.009 ether}(1);
    // }

    // // 送金額が多すぎる場合はリバートすることを確認
    // function test_Mint_RevertWhen_InvalidValue_TooHigh() public {
    //     vm.prank(alice);
    //     vm.expectRevert("OpenTransfer: Invalid value");
    //     nft.mint{value: 0.02 ether}(1);
    // }

    // 重要である理由: 発行にはお金がかかることに意味があるのではないか
    // 送金額が0の場合はリバートすることを確認
    function test_Mint_RevertWhen_ZeroValue() public {
        vm.prank(alice);
        vm.expectRevert("OpenTransfer: Invalid value");
        nft.mint{value: 0}(1);
    }

    // ============ TransferFrom Tests ============

    // // 所有者がtransferFromで自分のトークンを転送できることを確認
    // function test_TransferFrom_ByOwner() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);
    //
    //     vm.prank(alice);
    //     nft.transferFrom(alice, bob, 0);
    //
    //     assertEq(nft.ownerOf(0), bob);
    //     assertEq(nft.balanceOf(alice), 0);
    //     assertEq(nft.balanceOf(bob), 1);
    // }

    // // approve された人がトークンを転送できることを確認
    // function test_TransferFrom_ByApproved() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);
    //
    //     vm.prank(alice);
    //     nft.approve(bob, 0);
    //
    //     vm.prank(bob);
    //     nft.transferFrom(alice, charlie, 0);
    //
    //     assertEq(nft.ownerOf(0), charlie);
    // }

    // // setApprovalForAll でオペレーターに設定された人がトークンを転送できることを確認
    // function test_TransferFrom_ByApprovedForAll() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);
    //
    //     vm.prank(alice);
    //     nft.setApprovalForAll(bob, true);
    //
    //     vm.prank(bob);
    //     nft.transferFrom(alice, charlie, 0);
    //
    //     assertEq(nft.ownerOf(0), charlie);
    // }

    // 重要である理由: OpenTransfer機能の核心であるため
    // 承認されていない第三者でもトークンを転送できることを確認（OpenTransfer機能）
    function test_TransferFrom_OpenTransfer_ByAnyone() public {
        vm.prank(alice);
        nft.mint{value: 0.01 ether}(1);

        vm.prank(charlie);
        nft.transferFrom(alice, bob, 0);

        assertEq(nft.ownerOf(0), bob);
        assertEq(nft.balanceOf(alice), 0);
        assertEq(nft.balanceOf(bob), 1);
    }

    // 重要である理由: OpenTransfer イベントは OpenTransfer 機能の重要な部分であるため
    // 第三者による転送時に OpenTransfer イベントが発行されることを確認
    function test_TransferFrom_OpenTransfer_EmitsOpenTransferEvent() public {
        vm.prank(alice);
        nft.mint{value: 0.01 ether}(1);

        vm.prank(charlie);
        vm.expectEmit(true, true, true, true);
        emit OpenTransfer(charlie, alice, bob, 0);
        nft.transferFrom(alice, bob, 0);
    }

    // 重要である理由: 所有者と所有者以外の転送が区別できる点は、コントラクトからわかる思想のように思える
    // 所有者による転送時には OpenTransfer イベントが発行されないことを確認
    function test_TransferFrom_NoOpenTransferEvent_WhenOwner() public {
        vm.prank(alice);
        nft.mint{value: 0.01 ether}(1);

        vm.prank(alice);
        vm.recordLogs();
        nft.transferFrom(alice, bob, 0);

        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; i++) {
            bytes32 openTransferSig = keccak256("OpenTransfer(address,address,address,uint256)");
            assertTrue(logs[i].topics[0] != openTransferSig, "OpenTransfer event should not be emitted");
        }
    }

    // ============ SafeTransferFrom Tests ============

    // // 所有者が safeTransferFrom で自分のトークンを転送できることを確認
    // function test_SafeTransferFrom_ByOwner() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);
    //
    //     vm.prank(alice);
    //     nft.safeTransferFrom(alice, bob, 0);
    //
    //     assertEq(nft.ownerOf(0), bob);
    // }

    // // approve された人が safeTransferFrom でトークンを転送できることを確認
    // function test_SafeTransferFrom_ByApproved() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);
    //
    //     vm.prank(alice);
    //     nft.approve(bob, 0);
    //
    //     vm.prank(bob);
    //     nft.safeTransferFrom(alice, charlie, 0);
    //
    //     assertEq(nft.ownerOf(0), charlie);
    // }

    // // 承認されていない第三者でも safeTransferFrom でトークンを転送できることを確認（OpenTransfer機能）
    // function test_SafeTransferFrom_OpenTransfer_ByAnyone() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);

    //     vm.prank(charlie);
    //     nft.safeTransferFrom(alice, bob, 0);

    //     assertEq(nft.ownerOf(0), bob);
    // }

    // // 第三者による safeTransferFrom 時に OpenTransfer イベントが発行されることを確認
    // function test_SafeTransferFrom_OpenTransfer_EmitsOpenTransferEvent() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);
    //
    //     vm.prank(charlie);
    //     vm.expectEmit(true, true, true, true);
    //     emit OpenTransfer(charlie, alice, bob, 0);
    //     nft.safeTransferFrom(alice, bob, 0);
    // }

    // // データ付きの safeTransferFrom が正常に動作することを確認
    // function test_SafeTransferFrom_WithData() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);
    //
    //     vm.prank(charlie);
    //     nft.safeTransferFrom(alice, bob, 0, "test data");
    //
    //     assertEq(nft.ownerOf(0), bob);
    // }

    // ============ Edge Cases ============

    // // 存在しないトークンの転送はリバートすることを確認
    // function test_TransferFrom_RevertWhen_NonexistentToken() public {
    //     vm.prank(alice);
    //     vm.expectRevert("ERC721: operator query for nonexistent token");
    //     nft.transferFrom(alice, bob, 999);
    // }

    // 重要である理由: 誰でも転送できるが、それでもルールに従う必要がある。これには何らかのメッセージ性があるのではないか。
    // from アドレスが実際の所有者でない場合はリバートすることを確認
    function test_TransferFrom_RevertWhen_WrongFrom() public {
        vm.prank(alice);
        nft.mint{value: 0.01 ether}(1);

        vm.prank(charlie);
        vm.expectRevert("ERC721: transfer of token that is not own");
        nft.transferFrom(bob, charlie, 0);
    }

    // 重要である理由: 誰でも転送できるが、けしてバーンはできない。これには何らかのメッセージ性があるのではないか。
    // ゼロアドレスへの転送はリバートすることを確認
    function test_TransferFrom_ToZeroAddress_Reverts() public {
        vm.prank(alice);
        nft.mint{value: 0.01 ether}(1);

        vm.prank(alice);
        vm.expectRevert("ERC721: transfer to the zero address");
        nft.transferFrom(alice, address(0), 0);
    }

    // ============ Multiple Transfers Test ============

    // // 複数の第三者による連続転送が正常に動作することを確認
    // function test_MultipleOpenTransfers() public {
    //     vm.prank(alice);
    //     nft.mint{value: 0.01 ether}(1);
    //
    //     vm.prank(charlie);
    //     nft.transferFrom(alice, bob, 0);
    //     assertEq(nft.ownerOf(0), bob);
    //
    //     vm.prank(alice);
    //     nft.transferFrom(bob, charlie, 0);
    //     assertEq(nft.ownerOf(0), charlie);
    //
    //     vm.prank(bob);
    //     nft.transferFrom(charlie, alice, 0);
    //     assertEq(nft.ownerOf(0), alice);
    // }
}
