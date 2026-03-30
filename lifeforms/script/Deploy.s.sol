// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";

interface ILifeforms2 {
    function name() external view returns (string memory);
}

contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy Lifeforms2 contract
        // Constructor: (string name_, string symbol_, uint256 _maxDuration, uint256 price_)
        bytes memory bytecode = abi.encodePacked(
            vm.getCode("Lifeforms2.sol:Lifeforms2"),
            abi.encode("Lifeforms", "LIFE", 365 days, 0.01 ether)
        );

        address deployed;
        assembly {
            deployed := create(0, add(bytecode, 0x20), mload(bytecode))
        }
        require(deployed != address(0), "Deployment failed");

        vm.stopBroadcast();
    }
}
