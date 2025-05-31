// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./TrashToken.sol";
import "./TrashNFT.sol";
import { IRecyclingSystem } from "./RecyclingSystem.sol";

/**
 * @title QuestSystem
 * @dev Manages quests and rewards for the gamified recycling system
 */
contract QuestSystem is Ownable {
    TrashToken public trashToken;
    TrashNFT public trashNFT;
    IRecyclingSystem public recyclingSystem;

    // Quest types
    enum QuestType {
        FIRST_RECYCLER,    // Recycle anything once
        WEEKLY_WARRIOR,    // Recycle 5 items in a week
        EARTH_CHAMPION,    // Recycle 20 items total
        MATERIAL_MASTER    // Recycle all material types
    }

    struct Quest {
        string name;
        string description;
        uint256 requiredAmount;
        uint256 rewardAmount;  // TRASH tokens
        bool nftReward;        // if true, also mints NFT
        string nftURI;         // metadata URI for the NFT
    }

    // Mapping from quest type to quest details
    mapping(QuestType => Quest) public quests;
    
    // Mapping from email hash to quest progress
    mapping(bytes32 => mapping(QuestType => uint256)) public questProgress;
    
    // Mapping from email hash to recycled material types
    mapping(bytes32 => mapping(IRecyclingSystem.RecyclableType => bool)) public recycledMaterials;
    
    // Mapping from email hash to total recycled items
    mapping(bytes32 => uint256) public totalRecycled;
    
    // Mapping from email hash to weekly recycled items with timestamp
    mapping(bytes32 => mapping(uint256 => uint256)) public weeklyRecycled;
    
    // Mapping from email hash to claimed quests
    mapping(bytes32 => mapping(QuestType => bool)) public claimedQuests;
    
    // Mapping from email hash to wallet address (after verification)
    mapping(bytes32 => address) public verifiedWallets;

    event QuestCompleted(bytes32 indexed emailHash, QuestType questType);
    event RewardClaimed(address indexed wallet, QuestType questType, uint256 tokenAmount, uint256 nftId);
    event EmailVerified(bytes32 indexed emailHash, address indexed wallet);
    event RecyclingRecorded(bytes32 indexed emailHash, IRecyclingSystem.RecyclableType materialType, uint256 amount);

    constructor(
        address _trashToken,
        address _trashNFT,
        address _recyclingSystem
    ) Ownable(msg.sender) {
        trashToken = TrashToken(_trashToken);
        trashNFT = TrashNFT(_trashNFT);
        recyclingSystem = IRecyclingSystem(_recyclingSystem);
        
        // Initialize quests
        quests[QuestType.FIRST_RECYCLER] = Quest({
            name: "First Recycler",
            description: "Recycle anything once",
            requiredAmount: 1,
            rewardAmount: 10 * 10**18, // 10 TRASH tokens
            nftReward: true,
            nftURI: "ipfs://QmFirstRecyclerMetadata"
        });
        
        quests[QuestType.WEEKLY_WARRIOR] = Quest({
            name: "Weekly Warrior",
            description: "Recycle 5 items in a week",
            requiredAmount: 5,
            rewardAmount: 50 * 10**18, // 50 TRASH tokens
            nftReward: true,
            nftURI: "ipfs://QmWeeklyWarriorMetadata"
        });
        
        quests[QuestType.EARTH_CHAMPION] = Quest({
            name: "Earth Champion",
            description: "Recycle 20 items total",
            requiredAmount: 20,
            rewardAmount: 100 * 10**18, // 100 TRASH tokens
            nftReward: true,
            nftURI: "ipfs://QmEarthChampionMetadata"
        });
        
        quests[QuestType.MATERIAL_MASTER] = Quest({
            name: "Material Master",
            description: "Recycle all material types",
            requiredAmount: 3, // Number of different material types
            rewardAmount: 75 * 10**18, // 75 TRASH tokens
            nftReward: true,
            nftURI: "ipfs://QmMaterialMasterMetadata"
        });
    }

    /**
     * @dev Records recycling activity for a user
     * @param emailHash The hash of the user's email
     * @param materialType The type of material recycled
     * @param amount The amount recycled
     */
    function recordRecycling(
        bytes32 emailHash,
        IRecyclingSystem.RecyclableType materialType,
        uint256 amount
    ) external onlyOwner {
        require(emailHash != bytes32(0), "Invalid email hash");
        
        // Update total recycled
        totalRecycled[emailHash] += amount;
        
        // Update weekly recycled (using the current week number)
        uint256 currentWeek = block.timestamp / 1 weeks;
        weeklyRecycled[emailHash][currentWeek] += amount;
        
        // Mark material type as recycled
        recycledMaterials[emailHash][materialType] = true;
        
        // Update quest progress
        
        // First Recycler - just needs 1 recycling action
        if (questProgress[emailHash][QuestType.FIRST_RECYCLER] < quests[QuestType.FIRST_RECYCLER].requiredAmount) {
            questProgress[emailHash][QuestType.FIRST_RECYCLER] += amount;
            
            if (questProgress[emailHash][QuestType.FIRST_RECYCLER] >= quests[QuestType.FIRST_RECYCLER].requiredAmount) {
                emit QuestCompleted(emailHash, QuestType.FIRST_RECYCLER);
            }
        }
        
        // Weekly Warrior - needs 5 in the current week
        if (weeklyRecycled[emailHash][currentWeek] >= quests[QuestType.WEEKLY_WARRIOR].requiredAmount &&
            questProgress[emailHash][QuestType.WEEKLY_WARRIOR] < quests[QuestType.WEEKLY_WARRIOR].requiredAmount) {
            
            questProgress[emailHash][QuestType.WEEKLY_WARRIOR] = quests[QuestType.WEEKLY_WARRIOR].requiredAmount;
            emit QuestCompleted(emailHash, QuestType.WEEKLY_WARRIOR);
        }
        
        // Earth Champion - needs 20 total
        if (totalRecycled[emailHash] >= quests[QuestType.EARTH_CHAMPION].requiredAmount &&
            questProgress[emailHash][QuestType.EARTH_CHAMPION] < quests[QuestType.EARTH_CHAMPION].requiredAmount) {
            
            questProgress[emailHash][QuestType.EARTH_CHAMPION] = quests[QuestType.EARTH_CHAMPION].requiredAmount;
            emit QuestCompleted(emailHash, QuestType.EARTH_CHAMPION);
        }
        
        // Material Master - needs all material types
        uint256 materialTypeCount = 0;
        for (uint i = 0; i <= uint(IRecyclingSystem.RecyclableType.OTHER); i++) {
            if (recycledMaterials[emailHash][IRecyclingSystem.RecyclableType(i)]) {
                materialTypeCount++;
            }
        }
        
        if (materialTypeCount >= quests[QuestType.MATERIAL_MASTER].requiredAmount &&
            questProgress[emailHash][QuestType.MATERIAL_MASTER] < quests[QuestType.MATERIAL_MASTER].requiredAmount) {
            
            questProgress[emailHash][QuestType.MATERIAL_MASTER] = quests[QuestType.MATERIAL_MASTER].requiredAmount;
            emit QuestCompleted(emailHash, QuestType.MATERIAL_MASTER);
        }
        
        emit RecyclingRecorded(emailHash, materialType, amount);
    }

    /**
     * @dev Verifies a user's email and links it to their wallet address
     * @param emailHash The hash of the user's email
     * @param wallet The wallet address to link
     * @param proof The zkemail proof (placeholder for actual implementation)
     */
    function verifyEmail(bytes32 emailHash, address wallet, bytes memory proof) external {
        // In a real implementation, this would verify the zkemail proof
        // For now, we'll just link the email hash to the wallet
        
        require(emailHash != bytes32(0), "Invalid email hash");
        require(wallet != address(0), "Invalid wallet address");
        
        // Simple placeholder for zkemail verification
        // In production, this would validate the proof
        bytes32 proofHash = keccak256(proof);
        require(proofHash != bytes32(0), "Invalid proof");
        
        verifiedWallets[emailHash] = wallet;
        
        emit EmailVerified(emailHash, wallet);
    }

    /**
     * @dev Claims rewards for completed quests
     * @param emailHash The hash of the user's email
     * @param questType The type of quest to claim rewards for
     */
    function claimRewards(bytes32 emailHash, QuestType questType) external {
        address wallet = verifiedWallets[emailHash];
        require(wallet != address(0), "Email not verified");
        require(wallet == msg.sender, "Only verified wallet can claim");
        require(!claimedQuests[emailHash][questType], "Quest already claimed");
        require(questProgress[emailHash][questType] >= quests[questType].requiredAmount, "Quest not completed");
        
        // Mark as claimed
        claimedQuests[emailHash][questType] = true;
        
        // Mint TRASH tokens
        trashToken.mint(wallet, quests[questType].rewardAmount);
        
        // Mint NFT if applicable
        uint256 nftId = 0;
        if (quests[questType].nftReward) {
            nftId = trashNFT.mintNFT(wallet, uint256(questType), quests[questType].nftURI);
        }
        
        emit RewardClaimed(wallet, questType, quests[questType].rewardAmount, nftId);
    }

    /**
     * @dev Updates a quest's details
     * @param questType The type of quest to update
     * @param name The new name
     * @param description The new description
     * @param requiredAmount The new required amount
     * @param rewardAmount The new reward amount
     * @param nftReward Whether to reward an NFT
     * @param nftURI The new NFT URI
     */
    function updateQuest(
        QuestType questType,
        string memory name,
        string memory description,
        uint256 requiredAmount,
        uint256 rewardAmount,
        bool nftReward,
        string memory nftURI
    ) external onlyOwner {
        quests[questType] = Quest({
            name: name,
            description: description,
            requiredAmount: requiredAmount,
            rewardAmount: rewardAmount,
            nftReward: nftReward,
            nftURI: nftURI
        });
    }

    /**
     * @dev Gets the progress of a quest for a user
     * @param emailHash The hash of the user's email
     * @param questType The type of quest
     * @return progress The progress of the quest
     * @return required The required amount to complete the quest
     * @return completed Whether the quest is completed
     * @return claimed Whether the quest rewards have been claimed
     */
    function getQuestStatus(bytes32 emailHash, QuestType questType) external view returns (
        uint256 progress,
        uint256 required,
        bool completed,
        bool claimed
    ) {
        progress = questProgress[emailHash][questType];
        required = quests[questType].requiredAmount;
        completed = progress >= required;
        claimed = claimedQuests[emailHash][questType];
    }
}
