//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PoolTokenContract {
    using SafeERC20 for IERC20;

    struct CampaignPool {
        address owner;
        bool refundable;
        IERC20 token;
        uint amount;
    }

    struct UserRewardRequest {
        bytes32 poolId;
        address userAddress;
        uint amount;
    }

    mapping(bytes32 => CampaignPool) public campaignPool;
    mapping(address => mapping(bytes32 => uint)) public userPool;
    mapping(IERC20 => bool) public supportedTokens;
    mapping(bytes32 => uint) public specialPoolFee;
    uint public claimRewardFee;
    uint public  poolCreationFeePercentage;
    address private immutable owner;

    event RewardClaimed(address receiverAddr, uint amount, IERC20 token);
    event CampaignPoolCreated(address owner, IERC20 token, uint feeDeducted, uint finalAmount, bytes32 poolId);
    event CampaignPoolToppedUp(bytes32 poolId, uint newAmount);
    event CampaignPoolSet(bytes32 poolId, uint newValue);
    event RewardAssigned(bytes32 poolId, address receiverAddr, uint amount);
    event UserPoolSet(address addr, bytes32 poolId, uint newValue);
    event ClaimFeeSet(uint feeAmount);
    event CampaignPoolCreationFeePercentageSet(uint percentage);
    event CampaignPoolSetRefundable(bytes32 poolId);
    event CampaignPoolCancelled(bytes32 poolId, uint refundAmount, IERC20 token);

    constructor(uint claimFeeNative, uint initialPoolCreationFeePercentage) {
        require(poolCreationFeePercentage < 100, "Percentage must not be greater than 99");

        poolCreationFeePercentage = initialPoolCreationFeePercentage;
        claimRewardFee = claimFeeNative;
        owner = msg.sender;
    }

    function depositNative(bytes32 poolId) external payable {
        require(msg.value > 1, "Amount must be greater than 1");
        require(poolId != bytes32(0), "poolId is required");

        uint feePercentage;
        if (specialPoolFee[poolId] > 0) {
            feePercentage = specialPoolFee[poolId];
        } else {
            feePercentage = poolCreationFeePercentage;
        }

        uint feeAmount = (msg.value * feePercentage) / 100;
        uint poolSize = msg.value - feeAmount;

        if (feeAmount > 0) {
            (bool success,) = owner.call{value: feeAmount}("");
            require(success, "Native currency transfer failed");
        }

        CampaignPool storage pool = campaignPool[poolId];

        if (pool.amount == 0) {
            campaignPool[poolId] = CampaignPool(msg.sender, false, IERC20(address(0)), poolSize);
            emit CampaignPoolCreated(msg.sender, pool.token, feeAmount, pool.amount, poolId);
        } else {
            require(address(pool.token) == address(0), "IERC20 based reward pool with the following id is already created, please use a different id");
            pool.amount += poolSize;
            emit CampaignPoolToppedUp(poolId, pool.amount);
        }
    }

    function depositERC20(bytes32 poolId, IERC20 token, uint amount) external {
        require(amount > 1, "Amount must be greater than 1");
        require(poolId != bytes32(0), "poolId is required");
        require(supportedTokens[token] == true, "Token is not supported");

        uint feePercentage;
        if (specialPoolFee[poolId] > 0) {
            feePercentage = specialPoolFee[poolId];
        } else {
            feePercentage = poolCreationFeePercentage;
        }

        uint feeAmount = (amount * feePercentage) / 100;
        uint poolSize = amount - feeAmount;

        token.safeTransferFrom(msg.sender, address(this), poolSize);
        token.safeTransferFrom(msg.sender, owner, feeAmount);

        CampaignPool storage pool = campaignPool[poolId];
        if (pool.amount == 0) {
            campaignPool[poolId] = CampaignPool(msg.sender, false, token, poolSize);
        } else {
            require(address(pool.token) != address(0), "Native chain currency based reward pool with the given id is already created, please use a different id");
            require(pool.token == token, "IERC20 based reward pool with given id using a different token is already created, please use a different id");

            pool.amount += poolSize;
        }

        emit CampaignPoolCreated(msg.sender, token, feeAmount, poolSize, poolId);
    }

    function cancel(bytes32 poolId) external {
        require(poolId != bytes32(0), "poolId is required");

        CampaignPool memory pool = campaignPool[poolId];

        require(msg.sender == owner || msg.sender == pool.owner, "Only pool owner can cancel");
        require(pool.refundable, "Campaign is not refundable");
        require(pool.amount > 0, "Pool is empty");

        delete campaignPool[poolId];
        delete specialPoolFee[poolId];

        if (address(pool.token) == address(0)) {
            (bool success,) = msg.sender.call{value: pool.amount}("");
            require(success, "Transfer failed");
        } else {
            IERC20 token = IERC20(pool.token);
            token.safeTransfer(msg.sender, pool.amount);
        }

        emit CampaignPoolCancelled(poolId, pool.amount, pool.token);
    }

    function claimReward(bytes32 poolId) external payable {
        require(poolId != bytes32(0), "poolId is required");
        require(msg.value >= claimRewardFee, string.concat("This function requires a feeAmount of: ", Strings.toString(claimRewardFee)));

        uint amountToClaim = userPool[msg.sender][poolId];
        require(amountToClaim > 0, "Amount to claim is zero");

        CampaignPool memory pool = campaignPool[poolId];

        delete userPool[msg.sender][poolId];

        if (address(pool.token) == address(0)) {
            (bool success,) = msg.sender.call{value: amountToClaim}("");
            require(success, "Transfer failed");
        } else {
            IERC20 token = IERC20(pool.token);
            token.safeTransfer(msg.sender, amountToClaim);
        }
        emit RewardClaimed(msg.sender, pool.amount, pool.token);
    }

    function assignRewards(UserRewardRequest[] memory request) external onlyOwner {
        for (uint i = 0; i < request.length; i++) {
            address user = request[i].userAddress;
            bytes32 poolId = request[i].poolId;
            uint amount = request[i].amount;
            bool canSend = campaignPool[poolId].amount >= amount;

            if (canSend) {
                campaignPool[poolId].amount -= amount;
                userPool[user][poolId] += amount;
                emit RewardAssigned(poolId, user, amount);
            }
        }
    }

    function addErc20Token(address token) external onlyOwner {
        require(token != address(0), "Token address is required");

        supportedTokens[IERC20(token)] = true;
    }

    function withdrawNative(uint amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");

        (bool success,) = owner.call{value: amount}("");
        require(success, "Transfer failed");
    }

    function withdrawERC20(address tokenAddr, uint amount) external onlyOwner {
        require(tokenAddr != address(0), "Token address is required");
        require(amount > 0, "Amount must be greater than 0");

        IERC20 token = IERC20(tokenAddr);
        require(supportedTokens[token] == true, "Token is not supported");

        token.safeTransfer(owner, amount);
    }

    function setDefaultPoolCreationFeePercentage(uint creationFeePercentage) external onlyOwner {
        require(creationFeePercentage < 100, "Percentage must not be greater thatn 99");

        poolCreationFeePercentage = creationFeePercentage;

        emit CampaignPoolCreationFeePercentageSet(creationFeePercentage);
    }

    function setCustomPoolCreationFeePercentagee(bytes32 poolId, uint percentage) external onlyOwner {
        require(percentage < 100, "Percentage must not be greater than 99");
        require(poolId != bytes32(0), "poolId is required");

        specialPoolFee[poolId] = percentage;
    }

    function setUserPool(address user, bytes32 poolId, uint amount) external onlyOwner {
        require(poolId != bytes32(0), "poolId is required");
        require(user != address(0), "Address is required");

        userPool[user][poolId] = amount;

        emit UserPoolSet(user, poolId, amount);
    }

    function setCampaignPool(bytes32 poolId, uint amount) external onlyOwner {
        require(poolId != bytes32(0), "poolId is required");

        campaignPool[poolId].amount = amount;

        emit CampaignPoolSet(poolId, amount);
    }

    function setRefundable(bytes32 poolId) external onlyOwner {
        require(poolId != bytes32(0), "poolId is required");

        campaignPool[poolId].refundable = true;

        emit CampaignPoolSetRefundable(poolId);
    }

    function setClaimFee(uint claimFee) external onlyOwner {
        claimRewardFee = claimFee;

        emit ClaimFeeSet(claimFee);
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only the owner can execute this function");
        _;
    }
}
