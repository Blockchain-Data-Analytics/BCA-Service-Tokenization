// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BCAServiceContract is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public tokToken;
    uint256 public deposit;
    uint256 public retracted;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public tickPrice;
    address public userAddress;
    address public providerAddress;

    event DepositMade(address user, uint256 amount);
    event ServiceStopped(uint256 endTime);
    event Withdrawn(address recipient, uint256 amount);
    event Retracted(address recipient, uint256 amount);

    error AlreadySubscribed();
    error AlreadyStopped();
    error InsufficientBalance(uint256 availableBalance);
    error NotStarted();
    error UnAuthorized();

    constructor(address _providerAddress, address _tokAddress, uint256 _tickPrice) {
        tokToken = IERC20(_tokAddress);
        tickPrice = _tickPrice;
        providerAddress = _providerAddress;
    }

    function makeDeposit(uint256 amount) external nonReentrant {
        // require(amount > 0, "Deposit must be greater than 0"); by type!
        if (! (userAddress == address(0) || userAddress == msg.sender)) {
            revert AlreadySubscribed();
        }

        // allowance for the amount must be given by sender
        tokToken.safeTransferFrom(msg.sender, address(this), amount);

        // remember user who made first deposit (e.g. subscribed)
        if (userAddress == address(0)) {
            userAddress = msg.sender;
            startTime = block.timestamp;
        }
        deposit += amount;
        emit DepositMade(msg.sender, amount);
    }

    function stop() external {
        if (! (msg.sender == userAddress || msg.sender == providerAddress)) {
            revert UnAuthorized();
        }
        if (endTime != 0) {
            revert AlreadyStopped();
        }

        endTime = block.timestamp;
        emit ServiceStopped(endTime);
    }

    function balanceUser() public view returns (uint256) {
        if (userAddress == address(0)) {
            revert NotStarted();
        }
        if (startTime == 0) {
            revert NotStarted();
        }

        uint256 calcTime = endTime != 0 ? endTime : block.timestamp;
        uint256 duration = calcTime - startTime;
        uint256 paid = duration * tickPrice;

        if (paid >= deposit) {
            return 0;
        } else {
            return deposit - paid;
        }
    }

    function balanceProvider() public view returns (uint256) {
        if (msg.sender != providerAddress) {
            revert UnAuthorized();
        }
        if (startTime == 0) {
            revert NotStarted();
        }

        uint256 calcTime = endTime != 0 ? endTime : block.timestamp;
        uint256 ticks = calcTime - startTime;
        uint256 balance = ticks * tickPrice - retracted;
        // tokToken.approve(providerAddress, balance);
        return balance;
    }

    function withdrawUser(uint256 amount) external nonReentrant {
        if (msg.sender != userAddress) {
            revert UnAuthorized();
        }
        uint256 balance = balanceUser();
        if (balance < amount) {
            revert InsufficientBalance(balance);
        }

        deposit -= amount;
        tokToken.transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);

        // stop service?
        if (deposit == 0) {
            this.stop();
        }
    }

    function withdrawProvider(uint256 amount) external nonReentrant {
        if (msg.sender != providerAddress) {
            revert UnAuthorized();
        }
        uint256 balance = balanceProvider();
        if (balance < amount) {
            revert InsufficientBalance(balance);
        }

        retracted += amount;
        tokToken.transfer(msg.sender, amount);
        emit Retracted(msg.sender, amount);
    }
}