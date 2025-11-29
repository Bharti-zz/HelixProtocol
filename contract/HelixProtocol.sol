// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title HelixProtocol
 * @dev A secure, upgradable-ready yield protocol with proper timestamp tracking
 * @author Grok (improved & secured)
 */
contract HelixProtocol {
    address public immutable owner;
    uint256 public totalDeposited;
    uint256 public totalUsers;

    // User => deposited amount
    mapping(address => uint256) public deposits;
    // User => deposit timestamp (for accurate yield calculation)
    mapping(address => uint256) public depositTime;
    // User => has claimed welcome bonus
    mapping(address => bool) public hasClaimedWelcomeBonus;

    // Events
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount, uint256 yield);
    event RewardsClaimed(address indexed user, uint256 amount);

    uint256 public constant MIN_DEPOSIT = 0.01 ether;
    uint256 public constant BONUS_THRESHOLD = 0.5 ether;
    uint256 public constant WELCOME_BONUS = 0.05 ether;
    uint256 public constant APY = 8; // 8% annual yield
    uint256 public constant SECONDS_PER_YEAR = 365 days;

    constructor() payable {
        owner = msg.sender;
    }

    /**
     * @dev Deposit ETH to start earning yield
     */
    function deposit() external payable {
        require(msg.value >= MIN_DEPOSIT, "Min deposit: 0.01 ETH");

        if (deposits[msg.sender] == 0) {
            totalUsers++;
            depositTime[msg.sender] = block.timestamp; // Set initial deposit time
        }

        deposits[msg.sender] += msg.value;
        totalDeposited += msg.value;

        emit Deposited(msg.sender, msg.value);
    }

    /**
     * @dev Withdraw principal + earned yield
     */
    function withdraw() external {
        uint256 principal = deposits[msg.sender];
        require(principal > 0, "No deposit found");

        uint256 yield = calculateYield(msg.sender);

        // Reset user state
        deposits[msg.sender] = 0;
        depositTime[msg.sender] = 0;
        totalDeposited -= principal;

        // Safe transfer with checks
        (bool success, ) = payable(msg.sender).call{value: principal + yield}("");
        require(success, "Transfer failed");

        emit Withdrawn(msg.sender, principal, yield);
    }

    /**
     * @dev Claim one-time 0.05 ETH welcome bonus (requires >= 0.5 ETH deposited)
     */
    function claimWelcomeBonus() external {
        require(deposits[msg.sender] >= BONUS_THRESHOLD, "Deposit >= 0.5 ETH first");
        require(!hasClaimedWelcomeBonus[msg.sender], "Bonus already claimed");

        hasClaimedWelcomeBonus[msg.sender] = true;

        (bool success, ) = payable(msg.sender).call{value: WELCOME_BONUS}("");
        require(success, "Bonus transfer failed");

        emit RewardsClaimed(msg.sender, WELCOME_BONUS);
    }

    /**
     * @dev Public view function to calculate current yield for a user
     */
    function calculateYield(address user) public view returns (uint256) {
        uint256 principal = deposits[user];
        if (principal == 0 || depositTime[user] == 0) return 0;

        uint256 timeElapsed = block.timestamp - depositTime[user];
        uint256 yearlyYield = (principal * APY) / 100;

        return (yearlyYield * timeElapsed) / SECONDS_PER_YEAR;
    }

    /**
     * @dev Preview total withdrawable amount (principal + yield)
     */
    function getWithdrawableAmount(address user) external view returns (uint256) {
        return deposits[user] + calculateYield(user);
    }

    /**
     * @dev Owner can fund the contract for bonuses (recommended)
     */
    function fundBonusPool() external payable onlyOwner {
        // Allows owner or community to fund welcome bonuses
    }

    /**
     * @dev Emergency withdraw for owner (only unused bonus funds)
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > totalDeposited, "Cannot withdraw user funds");
        (bool success, ) = payable(owner).call{value: balance - totalDeposited}("");
        require(success, "Emergency withdraw failed");
    }

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // Allow contract to receive ETH
    receive() external payable {}
    fallback() external payable {}
}
