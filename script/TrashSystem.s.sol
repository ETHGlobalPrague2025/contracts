// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import "../src/TrashToken.sol";
import "../src/TrashNFT.sol";
import "../src/QuestSystem.sol";
import { RecyclingSystem } from "../src/RecyclingSystem.sol";
import "../src/TestUSDC.sol";

/**
 * @title TrashSystemScript
 * @dev Deploys all contracts for the GARBAGE project in a single script
 * Uses a phased deployment approach to avoid transaction sequencing issues
 */
contract TrashSystemScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying contracts from address:", deployer);
        
        // Phase 1: Deploy TestUSDC
        vm.startBroadcast(deployerPrivateKey);
        TestUSDC usdc = new TestUSDC();
        vm.stopBroadcast();
        console.log("TestUSDC deployed at:", address(usdc));
        
        // Phase 2: Deploy RecyclingSystem
        vm.startBroadcast(deployerPrivateKey);
        RecyclingSystem recyclingSystem = new RecyclingSystem(address(usdc));
        vm.stopBroadcast();
        console.log("RecyclingSystem deployed at:", address(recyclingSystem));
        
        // Phase 3: Deploy TrashToken
        vm.startBroadcast(deployerPrivateKey);
        TrashToken trashToken = new TrashToken();
        vm.stopBroadcast();
        console.log("TrashToken deployed at:", address(trashToken));
        
        // Phase 4: Deploy TrashNFT
        vm.startBroadcast(deployerPrivateKey);
        TrashNFT trashNFT = new TrashNFT();
        vm.stopBroadcast();
        console.log("TrashNFT deployed at:", address(trashNFT));
        
        // Phase 5: Deploy QuestSystem
        vm.startBroadcast(deployerPrivateKey);
        QuestSystem questSystem = new QuestSystem(
            address(trashToken),
            address(trashNFT),
            address(recyclingSystem)
        );
        vm.stopBroadcast();
        console.log("QuestSystem deployed at:", address(questSystem));
        
        // Phase 6: Transfer ownership
        vm.startBroadcast(deployerPrivateKey);
        trashToken.transferOwnership(address(questSystem));
        trashNFT.transferOwnership(address(questSystem));
        console.log("Ownership of tokens transferred to QuestSystem");
        
        // Mint test USDC to the deployer
        uint256 mintAmount = 10000 * 10**6; // 10,000 USDC (with 6 decimals)
        usdc.mint(mintAmount);
        console.log("Minted", mintAmount, "test USDC to deployer:", deployer);
        vm.stopBroadcast();
        
        // Print summary of deployed contracts
        console.log("\n=== GARBAGE System Deployment Summary ===");
        console.log("TestUSDC:        ", address(usdc));
        console.log("RecyclingSystem: ", address(recyclingSystem));
        console.log("TrashToken:      ", address(trashToken));
        console.log("TrashNFT:        ", address(trashNFT));
        console.log("QuestSystem:     ", address(questSystem));
        console.log("=======================================");
    }
}
