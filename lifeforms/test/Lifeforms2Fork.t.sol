// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

interface ILifeforms2 {
    function maxDuration() external view returns (uint256);
    function price() external view returns (uint256);
    function isOpen() external view returns (bool);
    function owner() external view returns (address);
    function gravedigger() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function baseURI() external view returns (string memory);
    function contractURI() external view returns (string memory);
}

/// @notice Polygon mainnet フォークテスト
/// デプロイ済みコントラクトの実際の設定値を確認する。
contract Lifeforms2ForkTest is Test {
    ILifeforms2 lf;

    address constant DEPLOYED_ADDRESS = 0x8916eDD9b39783D85303Ecc6613917DdD735d88d;

    function setUp() public {
        vm.createSelectFork("polygon");
        lf = ILifeforms2(DEPLOYED_ADDRESS);
    }

    // IMPORTANT: 実際のインスタンス設定なので
    // メインネットで設定されている寿命の時間を確認する。
    // デプロイスクリプトでは 365 days だが、owner が変更している可能性がある。
    function test_Fork_MaxDuration() public {
        uint256 duration = lf.maxDuration();
        emit log_named_uint("maxDuration (seconds)", duration);
        emit log_named_uint("maxDuration (days)", duration / 1 days);

        // 値が 0 でないことを確認（設定されている）
        assertGt(duration, 0, "maxDuration should be set");
    }
}
