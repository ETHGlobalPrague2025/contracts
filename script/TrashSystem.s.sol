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
 */
contract TrashSystemScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Deploy TestUSDC
        TestUSDC usdc = new TestUSDC();
        console.log("TestUSDC deployed at:", address(usdc));
        
        // Step 2: Deploy RecyclingSystem with TestUSDC address
        RecyclingSystem recyclingSystem = new RecyclingSystem(address(usdc));
        console.log("RecyclingSystem deployed at:", address(recyclingSystem));
        
        // Step 3: Deploy the TRASH token
        TrashToken trashToken = new TrashToken();
        console.log("TrashToken deployed at:", address(trashToken));
        
        // Step 4: Deploy the TrashNFT contract
        TrashNFT trashNFT = new TrashNFT();
        console.log("TrashNFT deployed at:", address(trashNFT));
        
        // Step 5: Deploy the QuestSystem contract
        QuestSystem questSystem = new QuestSystem(
            address(trashToken),
            address(trashNFT),
            address(recyclingSystem)
        );
        console.log("QuestSystem deployed at:", address(questSystem));
        
        // Step 6: Transfer ownership of the token contracts to the QuestSystem
        trashToken.transferOwnership(address(questSystem));
        trashNFT.transferOwnership(address(questSystem));
        
        console.log("Ownership of tokens transferred to QuestSystem");
        
        // Optional: Mint some test USDC to the deployer for testing
        uint256 mintAmount = 10000 * 10**6; // 10,000 USDC (with 6 decimals)
        usdc.mint(mintAmount);
        console.log("Minted", mintAmount, "test USDC to deployer:", msg.sender);

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
