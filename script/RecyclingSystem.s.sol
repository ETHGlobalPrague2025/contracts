// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RecyclingSystem} from "../src/RecyclingSystem.sol";
import {TestUSDC} from "../src/TestUSDC.sol";

contract RecyclingSystemScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy TestUSDC
        TestUSDC usdc = new TestUSDC();
        console.log("TestUSDC deployed at:", address(usdc));

        // Deploy RecyclingSystem with TestUSDC address
        RecyclingSystem recyclingSystem = new RecyclingSystem(address(usdc));
        console.log("RecyclingSystem deployed at:", address(recyclingSystem));

        vm.stopBroadcast();
    }

    function mintTestTokens(address usdc, address to, uint256 amount) public {
        vm.startBroadcast();
        TestUSDC(usdc).mint(amount);
        vm.stopBroadcast();
        console.log("Minted", amount, "test USDC to", to);
    }
}
