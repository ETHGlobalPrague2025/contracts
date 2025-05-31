# Smart Contract ABIs

## Overview of Contracts

1. **RecyclingSystem** - Core contract for managing garbage cans, staking, and recycling operations
2. **QuestSystem** - Gamification layer that rewards users for recycling activities
3. **TrashToken** - ERC20 token used as a reward in the ecosystem
4. **TrashNFT** - ERC721 NFT awarded for completing quests
5. **TestUSDC** - Test stablecoin for development and testing purposes

## RecyclingSystem

The RecyclingSystem contract manages the physical garbage cans, allowing users to stake funds to deploy new cans, update fill levels, and purchase collected recyclable materials.

```javascript
const RecyclingSystemABI = [
  "function usdc() external view returns (address)",
  "function garbageCans(uint256) external view returns (uint256 id, string location,uint256 currentValue, bool isActive, bool isLocked, uint256 deploymentTimestamp, uint256 lastEmptiedTimestamp, uint256 totalStaked)",
  "function pendingRewards(address) external view returns (uint256)",
  "function PLATFORM_FEE_PERCENT() external view returns (uint256)",
  "function getGarbageCanInfo(uint256 garbageCanId) external view returns (string location, uint256 currentValue, bool isActive, bool isLocked, uint256 deploymentTimestamp, uint256 lastEmptiedTimestamp, uint256 totalStaked)",
  "function getStakerShare(uint256 garbageCanId, address staker) external view returns (uint256)",
  
  "function createPendingGarbageCan(string memory location, uint256 targetAmount) external",
  "function stakeForGarbageCan(uint256 pendingGarbageCanId, uint256 amount) external",
  "function updateFillLevel(uint256 garbageCanId, uint8 recyclableType, uint256 amount, uint256 value) external",
  "function buyContents(uint256 garbageCanId) external",
  "function withdrawRewards() external",
  
  "event GarbageCanCreated(uint256 indexed id, string location)",
  "event StakeDeposited(uint256 indexed pendingGarbageCanId, address indexed staker, uint256 amount)",
  "event GarbageCanDeployed(uint256 indexed pendingGarbageCanId, uint256 indexed garbageCanId)",
  "event FillLevelUpdated(uint256 indexed garbageCanId, uint8 recyclableType, uint256 amount, uint256 value)",
  "event ContentsPurchased(uint256 indexed garbageCanId, address indexed collector, uint256 value)",
  "event RewardsWithdrawn(address indexed staker, uint256 amount)"
];
```

### RecyclableType Enum

```javascript
const RecyclableType = {
  PLASTIC: 0,
  METAL: 1,
  OTHER: 2
};
```

## QuestSystem

The QuestSystem contract manages quests and rewards for the gamified recycling system, tracking user progress and distributing rewards.

```javascript
const QuestSystemABI = [
  "function trashToken() external view returns (address)",
  "function trashNFT() external view returns (address)",
  "function recyclingSystem() external view returns (address)",
  "function quests(uint8) external view returns (string name, string description, uint256 requiredAmount, uint256 rewardAmount, bool nftReward, string nftURI)",
  "function questProgress(bytes32, uint8) external view returns (uint256)",
  "function recycledMaterials(bytes32, uint8) external view returns (bool)",
  "function totalRecycled(bytes32) external view returns (uint256)",
  "function weeklyRecycled(bytes32, uint256) external view returns (uint256)",
  "function claimedQuests(bytes32, uint8) external view returns (bool)",
  "function verifiedWallets(bytes32) external view returns (address)",
  "function getQuestStatus(bytes32 emailHash, uint8 questType) external view returns (uint256 progress, uint256 required, bool completed, bool claimed)",
  
  "function recordRecycling(bytes32 emailHash, uint8 materialType, uint256 amount) external",
  "function verifyEmail(bytes32 emailHash, address wallet, bytes memory proof) external",
  "function claimRewards(bytes32 emailHash, uint8 questType) external",
  "function updateQuest(uint8 questType, string memory name, string memory description, uint256 requiredAmount, uint256 rewardAmount, bool nftReward, string memory nftURI) external",
  
  "event QuestCompleted(bytes32 indexed emailHash, uint8 questType)",
  "event RewardClaimed(address indexed wallet, uint8 questType, uint256 tokenAmount, uint256 nftId)",
  "event EmailVerified(bytes32 indexed emailHash, address indexed wallet)",
  "event RecyclingRecorded(bytes32 indexed emailHash, uint8 materialType, uint256 amount)"
];
```

### QuestType Enum

```javascript
const QuestType = {
  FIRST_RECYCLER: 0,    // Recycle anything once
  WEEKLY_WARRIOR: 1,    // Recycle 5 items in a week
  EARTH_CHAMPION: 2,    // Recycle 20 items total
  MATERIAL_MASTER: 3    // Recycle all material types
};
```

## TrashToken

The TrashToken is an ERC20 token used as a reward in the gamified recycling system.

```javascript
const TrashTokenABI = [
  "function name() external view returns (string)",
  "function symbol() external view returns (string)",
  "function decimals() external view returns (uint8)",
  "function totalSupply() external view returns (uint256)",
  "function balanceOf(address account) external view returns (uint256)",
  "function transfer(address to, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)",
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function transferFrom(address from, address to, uint256 amount) external returns (bool)",
  
  "function owner() external view returns (address)",
  "function transferOwnership(address newOwner) external",
  "function renounceOwnership() external",
  "function mint(address to, uint256 amount) external",
  
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "event Approval(address indexed owner, address indexed spender, uint256 value)",
  "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)"
];
```

## TrashNFT

```javascript
const TrashNFTABI = [
  "function name() external view returns (string)",
  "function symbol() external view returns (string)",
  "function tokenURI(uint256 tokenId) external view returns (string)",
  "function balanceOf(address owner) external view returns (uint256)",
  "function ownerOf(uint256 tokenId) external view returns (address)",
  "function safeTransferFrom(address from, address to, uint256 tokenId) external",
  "function transferFrom(address from, address to, uint256 tokenId) external",
  "function approve(address to, uint256 tokenId) external",
  "function getApproved(uint256 tokenId) external view returns (address)",
  "function setApprovalForAll(address operator, bool approved) external",
  "function isApprovedForAll(address owner, address operator) external view returns (bool)",
  
  "function tokenQuests(uint256) external view returns (uint256)",
  "function mintNFT(address to, uint256 questId, string memory tokenURI) external returns (uint256)",
  "function getQuestId(uint256 tokenId) external view returns (uint256)",
  
  "function owner() external view returns (address)",
  "function transferOwnership(address newOwner) external",
  "function renounceOwnership() external",
  
  "event Transfer(address indexed from, address indexed to, uint256 indexed tokenId)",
  "event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId)",
  "event ApprovalForAll(address indexed owner, address indexed operator, bool approved)",
  "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)"
];
```

## TestUSDC

```javascript
const TestUSDCABI = [
  // View Functions
  "function name() external view returns (string)",
  "function symbol() external view returns (string)",
  "function decimals() external view returns (uint8)",
  "function totalSupply() external view returns (uint256)",
  "function balanceOf(address account) external view returns (uint256)",
  "function allowance(address owner, address spender) external view returns (uint256)",
  
  "function mint(uint256 amount) external",
  "function transfer(address to, uint256 amount) external returns (bool)",
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function transferFrom(address from, address to, uint256 amount) external returns (bool)",
  
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "event Approval(address indexed owner, address indexed spender, uint256 value)"
];
```

## Contract Explanations

### RecyclingSystem

The RecyclingSystem contract is the core of the GARBAGE project, managing the physical infrastructure of garbage cans and the economic incentives around recycling. Key features include:

1. **Garbage Can Deployment**: Users can stake USDC to fund the deployment of new garbage cans in specific locations.
2. **Staking Mechanism**: Multiple users can stake funds for a single garbage can and receive proportional shares of future rewards.
3. **Recycling Operations**: The contract tracks the fill level and value of recyclable materials in each garbage can.
4. **Material Purchase**: Collectors can purchase the contents of garbage cans, with a portion of the payment distributed to stakers as rewards.
5. **Reward Distribution**: Stakers earn rewards based on their proportional stake in each garbage can.

### QuestSystem

The QuestSystem contract adds a gamification layer to the recycling ecosystem, encouraging user participation through quests and rewards. Key features include:

1. **Quest Management**: Defines various quests with specific requirements and rewards.
2. **Progress Tracking**: Tracks user progress toward completing quests based on their recycling activities.
3. **Email Verification**: Links email addresses to wallet addresses for user identification.
4. **Reward Distribution**: Distributes TRASH tokens and NFTs as rewards for completing quests.
5. **Quest Types**: Includes different types of quests such as first-time recycling, weekly goals, total recycling milestones, and diversity of materials recycled.