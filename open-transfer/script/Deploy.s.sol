// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import "forge-std/Script.sol";
import "../src/OpenTransfer.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();
        new OpenTransfer();
        vm.stopBroadcast();
    }
}
