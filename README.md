# Recycling System Smart Contract

A decentralized recycling system that enables community-driven garbage can deployment and rewards for recycling activities.

## Setup

```bash
forge install
```

## Test

```bash
forge test
```

## Build

```bash
forge build
```

## Deploy

```bash
# Deploy both TestUSDC and RecyclingSystem
forge script script/RecyclingSystem.s.sol:RecyclingSystemScript --rpc-url <your-rpc-url> --broadcast

# Mint test USDC tokens (amount in USDC with 6 decimals, e.g. 1000000 = 1 USDC)
forge script script/RecyclingSystem.s.sol:RecyclingSystemScript --sig "mintTestTokens(address,address,uint256)" <usdc-address> <recipient-address> <amount> --rpc-url <your-rpc-url> --broadcast
```

## Test USDC

```javascript
// Mint 1 USDC (1000000 = 1 USDC due to 6 decimals)
await testUsdc.mint(1000000);

// Approve RecyclingSystem to spend USDC
await testUsdc.approve(recyclingSystemAddress, ethers.constants.MaxUint256);
```

## Contract Addresses
FLOW Testnet:
  TestUSDC deployed at: 0x566B40Dd59A868c244E1353368e08ddaD1C1d74f
  RecyclingSystem deployed at: 0x0EFafca24E5BbC1C01587B659226B9d600fd671f


## Data Structures

### Enums

```solidity
enum RecyclableType { PLASTIC, METAL, OTHER }
```

### Structs

```solidity
struct Deposit {
    RecyclableType recyclableType;
    uint256 amount;
    uint256 value;
    uint256 timestamp;
}

struct GarbageCan {
    uint256 id;
    string location;
    uint256 currentValue;
    bool isActive;
    bool isLocked;
    uint256 deploymentTimestamp;
    uint256 lastEmptiedTimestamp;
    mapping(address => uint256) stakerShares;
    address[] stakers;
    uint256 totalStaked;
}

struct PendingGarbageCan {
    string location;
    uint256 totalStaked;
    uint256 targetAmount;
    mapping(address => uint256) stakes;
    address[] stakers;
    bool deployed;
    uint256 deployedGarbageCanId;
}
```

## Constants

- `PLATFORM_FEE_PERCENT`: 50 (Buyers pay 50% of the garbage can's value)
- `BASIS_POINTS`: 10000 (used for percentage calculations)

## Events

```solidity
event GarbageCanCreated(uint256 indexed id, string location)
event StakeDeposited(uint256 indexed pendingGarbageCanId, address indexed staker, uint256 amount)
event GarbageCanDeployed(uint256 indexed pendingGarbageCanId, uint256 indexed garbageCanId)
event FillLevelUpdated(uint256 indexed garbageCanId, RecyclableType recyclableType, uint256 amount, uint256 value)
event ContentsPurchased(uint256 indexed garbageCanId, address indexed collector, uint256 value)
event RewardsWithdrawn(address indexed staker, uint256 amount)
```

## API Reference

### Creating and Staking for Garbage Cans

#### `createPendingGarbageCan`
Creates a new pending garbage can that requires staking before deployment.

```solidity
function createPendingGarbageCan(string memory location, uint256 targetAmount) external
```

**Parameters:**
- `location`: Physical location of the garbage can
- `targetAmount`: Amount of USDC needed to deploy the garbage can

**Requirements:**
- `targetAmount` must be greater than 0
- `location` cannot be empty

#### `stakeForGarbageCan`
Allows users to stake USDC for a pending garbage can.

```solidity
function stakeForGarbageCan(uint256 pendingGarbageCanId, uint256 amount) external
```

**Parameters:**
- `pendingGarbageCanId`: ID of the pending garbage can
- `amount`: Amount of USDC to stake

**Requirements:**
- Must approve USDC spending first
- If amount exceeds remaining needed stake, only the needed amount is taken
- Automatically deploys garbage can when target amount is reached

### Managing Garbage Cans

#### `updateFillLevel`
Updates the fill level and value of a garbage can (called by garbage can device).

```solidity
function updateFillLevel(
    uint256 garbageCanId,
    RecyclableType recyclableType,
    uint256 amount,
    uint256 value
) external
```

**Parameters:**
- `garbageCanId`: ID of the garbage can
- `recyclableType`: Type of recyclable (PLASTIC, METAL, OTHER)
- `amount`: Amount being deposited
- `value`: Value of the deposit

#### `buyContents`
Allows collectors to purchase the contents of a garbage can.

```solidity
function buyContents(uint256 garbageCanId) external
```

**Parameters:**
- `garbageCanId`: ID of the garbage can to purchase contents from

**Requirements:**
- Must approve USDC spending first
- Must have enough USDC to pay 50% of the garbage can's current value

**Behavior:**
- Buyer pays 50% of the garbage can's current value in USDC
- Full payment amount is distributed to stakers based on their shares
- Resets the garbage can's value and updates lastEmptiedTimestamp

### Rewards and Information

#### `withdrawRewards`
Allows stakers to withdraw their pending rewards.

```solidity
function withdrawRewards() external
```

**Requirements:**
- Must have pending rewards to withdraw

#### `getGarbageCanInfo`
Returns information about a garbage can.

```solidity
function getGarbageCanInfo(uint256 garbageCanId) external view returns (
    string memory location,
    uint256 currentValue,
    bool isActive,
    bool isLocked,
    uint256 deploymentTimestamp,
    uint256 lastEmptiedTimestamp,
    uint256 totalStaked
)
```

**Parameters:**
- `garbageCanId`: ID of the garbage can

**Returns:**
- `location`: Physical location of the garbage can
- `currentValue`: Current value of contents
- `isActive`: Whether the can is active
- `isLocked`: Whether the can is locked
- `deploymentTimestamp`: When the can was deployed
- `lastEmptiedTimestamp`: When the can was last emptied
- `totalStaked`: Total amount staked for this can

#### `getStakerShare`
Returns the stake share of an address for a specific garbage can.

```solidity
function getStakerShare(uint256 garbageCanId, address staker) external view returns (uint256)
```

**Parameters:**
- `garbageCanId`: ID of the garbage can
- `staker`: Address of the staker

**Returns:**
- Stake share in basis points (100 = 1%)

## Example Usage

### Creating a New Garbage Can

1. Approve USDC spending:
```javascript
await usdc.approve(recyclingSystemAddress, ethers.constants.MaxUint256);
```

2. Create a pending garbage can:
```javascript
// 1 USDC = 1000000 (6 decimals)
await recyclingSystem.createPendingGarbageCan("123 Main St", 1000000);
```

3. Stake for the garbage can:
```javascript
await recyclingSystem.stakeForGarbageCan(pendingGarbageCanId, 500000); // 0.5 USDC
```

### Monitoring and Purchasing Contents

1. Get garbage can information:
```javascript
const info = await recyclingSystem.getGarbageCanInfo(garbageCanId);
```

2. Purchase contents:
```javascript
// Assuming current value is 2 USDC, buyer pays 1 USDC (50%)
await recyclingSystem.buyContents(garbageCanId);
```

3. Withdraw rewards:
```javascript
await recyclingSystem.withdrawRewards();
```
