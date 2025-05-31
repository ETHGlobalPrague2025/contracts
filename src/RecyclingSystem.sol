// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
}

interface IRecyclingSystem {
    enum RecyclableType { PLASTIC, METAL, OTHER }

    function getGarbageCanInfo(uint256 garbageCanId) external view returns (
        string memory location,
        uint256 currentValue,
        bool isActive,
        bool isLocked,
        uint256 deploymentTimestamp,
        uint256 lastEmptiedTimestamp,
        uint256 totalStaked
    );

    function getStakerShare(uint256 garbageCanId, address staker) external view returns (uint256);
}

contract RecyclingSystem is IRecyclingSystem {
    IERC20 public immutable usdc;

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

    uint256 private nextGarbageCanId;
    uint256 private nextPendingGarbageCanId;
    mapping(uint256 => GarbageCan) public garbageCans;
    mapping(uint256 => PendingGarbageCan) public pendingGarbageCans;
    mapping(address => uint256) public pendingRewards;
    uint256 public constant PLATFORM_FEE_PERCENT = 50; // Buyers pay 50% of the garbage can's value
    uint256 public constant BASIS_POINTS = 10000;

    constructor(address _usdc) {
        require(_usdc != address(0), "Invalid USDC address");
        usdc = IERC20(_usdc);
    }

    event GarbageCanCreated(uint256 indexed id, string location);
    event StakeDeposited(uint256 indexed pendingGarbageCanId, address indexed staker, uint256 amount);
    event GarbageCanDeployed(uint256 indexed pendingGarbageCanId, uint256 indexed garbageCanId);
    event FillLevelUpdated(uint256 indexed garbageCanId, RecyclableType recyclableType, uint256 amount, uint256 value);
    event ContentsPurchased(uint256 indexed garbageCanId, address indexed collector, uint256 value);
    event RewardsWithdrawn(address indexed staker, uint256 amount);

    modifier garbageCanExists(uint256 garbageCanId) {
        require(garbageCans[garbageCanId].deploymentTimestamp != 0, "Garbage can does not exist");
        _;
    }

    modifier pendingGarbageCanExists(uint256 pendingGarbageCanId) {
        require(pendingGarbageCans[pendingGarbageCanId].targetAmount != 0, "Pending garbage can does not exist");
        _;
    }

    modifier onlyActive(uint256 garbageCanId) {
        require(garbageCans[garbageCanId].isActive, "Garbage can is not active");
        _;
    }

    /**
     * @dev Creates a new pending garbage can that needs staking
     * @param location The physical location of the garbage can
     * @param targetAmount The amount of USDC needed to deploy the garbage can
     */
    function createPendingGarbageCan(string memory location, uint256 targetAmount) external {
        require(targetAmount > 0, "Target amount must be greater than 0");
        require(bytes(location).length > 0, "Location cannot be empty");

        uint256 pendingGarbageCanId = nextPendingGarbageCanId++;
        PendingGarbageCan storage newCan = pendingGarbageCans[pendingGarbageCanId];
        newCan.location = location;
        newCan.targetAmount = targetAmount;
        newCan.deployed = false;
    }

    /**
     * @dev Allows users to stake USDC for a pending garbage can
     * @param pendingGarbageCanId The ID of the pending garbage can
     * @param amount The amount of USDC to stake
     */
    function stakeForGarbageCan(uint256 pendingGarbageCanId, uint256 amount) external pendingGarbageCanExists(pendingGarbageCanId) {
        PendingGarbageCan storage pendingCan = pendingGarbageCans[pendingGarbageCanId];
        require(!pendingCan.deployed, "Garbage can already deployed");
        require(amount > 0, "Stake amount must be greater than 0");

        // Calculate how much more stake is needed
        uint256 remainingNeeded = 0;
        if (pendingCan.totalStaked < pendingCan.targetAmount) {
            remainingNeeded = pendingCan.targetAmount - pendingCan.totalStaked;
        }
        require(remainingNeeded > 0, "Target amount already reached");

        // Limit stake to remaining amount needed
        uint256 stakeAmount = amount > remainingNeeded ? remainingNeeded : amount;
        
        // Transfer USDC from staker to contract
        require(usdc.transferFrom(msg.sender, address(this), stakeAmount), "USDC transfer failed");

        if (pendingCan.stakes[msg.sender] == 0) {
            pendingCan.stakers.push(msg.sender);
        }
        pendingCan.stakes[msg.sender] += stakeAmount;
        pendingCan.totalStaked += stakeAmount;

        emit StakeDeposited(pendingGarbageCanId, msg.sender, stakeAmount);

        if (pendingCan.totalStaked >= pendingCan.targetAmount) {
            _deployGarbageCan(pendingGarbageCanId);
        }
    }

    /**
     * @dev Internal function to deploy a garbage can once target amount is reached
     * @param pendingGarbageCanId The ID of the pending garbage can
     */
    function _deployGarbageCan(uint256 pendingGarbageCanId) internal {
        PendingGarbageCan storage pendingCan = pendingGarbageCans[pendingGarbageCanId];
        uint256 garbageCanId = nextGarbageCanId++;
        
        GarbageCan storage newCan = garbageCans[garbageCanId];
        newCan.id = garbageCanId;
        newCan.location = pendingCan.location;
        newCan.isActive = true;
        newCan.deploymentTimestamp = block.timestamp;
        newCan.totalStaked = pendingCan.totalStaked;

        // Calculate and assign shares to stakers
        for (uint256 i = 0; i < pendingCan.stakers.length; i++) {
            address staker = pendingCan.stakers[i];
            uint256 share = (pendingCan.stakes[staker] * BASIS_POINTS) / pendingCan.totalStaked;
            newCan.stakerShares[staker] = share;
            newCan.stakers.push(staker);
        }

        pendingCan.deployed = true;
        pendingCan.deployedGarbageCanId = garbageCanId;

        emit GarbageCanDeployed(pendingGarbageCanId, garbageCanId);
        emit GarbageCanCreated(garbageCanId, pendingCan.location);
    }

    /**
     * @dev Updates the fill level and value of a garbage can (called by garbage can device)
     * @param garbageCanId The ID of the garbage can
     * @param recyclableType The type of recyclable being deposited
     * @param amount The amount being deposited
     * @param value The value of the deposit
     */
    function updateFillLevel(
        uint256 garbageCanId,
        RecyclableType recyclableType,
        uint256 amount,
        uint256 value
    ) external garbageCanExists(garbageCanId) onlyActive(garbageCanId) {
        GarbageCan storage can = garbageCans[garbageCanId];
        can.currentValue += value;
        
        emit FillLevelUpdated(garbageCanId, recyclableType, amount, value);
    }

    /**
     * @dev Allows collectors to purchase the contents of a garbage can
     * @param garbageCanId The ID of the garbage can to purchase contents from
     */
    function buyContents(uint256 garbageCanId) external garbageCanExists(garbageCanId) onlyActive(garbageCanId) {
        GarbageCan storage can = garbageCans[garbageCanId];
        uint256 paymentAmount = (can.currentValue * PLATFORM_FEE_PERCENT * 100) / BASIS_POINTS;
        
        // Transfer USDC from buyer to contract
        require(usdc.transferFrom(msg.sender, address(this), paymentAmount), "USDC transfer failed");
        
        // Distribute the payment to stakers based on their shares
        for (uint256 i = 0; i < can.stakers.length; i++) {
            address staker = can.stakers[i];
            uint256 reward = (paymentAmount * can.stakerShares[staker]) / BASIS_POINTS;
            pendingRewards[staker] += reward;
        }

        // Reset the garbage can
        can.currentValue = 0;
        can.lastEmptiedTimestamp = block.timestamp;
        
        emit ContentsPurchased(garbageCanId, msg.sender, paymentAmount);
    }

    /**
     * @dev Allows stakers to withdraw their pending rewards
     */
    function withdrawRewards() external {
        uint256 reward = pendingRewards[msg.sender];
        require(reward > 0, "No rewards to withdraw");

        pendingRewards[msg.sender] = 0;
        require(usdc.transfer(msg.sender, reward), "USDC transfer failed");

        emit RewardsWithdrawn(msg.sender, reward);
    }

    /**
     * @dev Returns information about a garbage can
     * @param garbageCanId The ID of the garbage can
     */
    function getGarbageCanInfo(uint256 garbageCanId) external view returns (
        string memory location,
        uint256 currentValue,
        bool isActive,
        bool isLocked,
        uint256 deploymentTimestamp,
        uint256 lastEmptiedTimestamp,
        uint256 totalStaked
    ) {
        GarbageCan storage can = garbageCans[garbageCanId];
        return (
            can.location,
            can.currentValue,
            can.isActive,
            can.isLocked,
            can.deploymentTimestamp,
            can.lastEmptiedTimestamp,
            can.totalStaked
        );
    }

    /**
     * @dev Returns the stake share of an address for a specific garbage can
     * @param garbageCanId The ID of the garbage can
     * @param staker The address of the staker
     */
    function getStakerShare(uint256 garbageCanId, address staker) external view returns (uint256) {
        return garbageCans[garbageCanId].stakerShares[staker];
    }
}
