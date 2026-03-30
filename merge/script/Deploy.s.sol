// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "forge-std/Script.sol";
import "../src/core/Merge.sol";
import "../src/core/MergeMetadata.sol";

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy MergeMetadata first
        MergeMetadata metadata = new MergeMetadata();

        // Deploy Merge contract
        // Parameters: registry, omnibus, metadataGenerator, pak
        // Using deployer address as placeholders for local testing
        address deployer = msg.sender;
        new Merge(
            deployer,           // registry (mock)
            deployer,           // omnibus
            address(metadata),  // metadataGenerator
            deployer            // pak
        );

        vm.stopBroadcast();
    }
}
