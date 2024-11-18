// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Iface_ServiceInstance.sol";

contract BCAServiceInstance is IServiceInstance, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // will be set in the constructor
    IERC20 public immutable tokToken;
    uint256 public immutable dayPrice;
    address public immutable providerAddress;
    address public immutable userAddress;

    uint256 public deposit;
    uint256 public retracted;
    uint256 public startTime;
    uint256 public endTime;

    event DepositMade(address user, uint256 amount);
    event ServiceStopped(uint256 ticks);
    event Withdrawn(address recipient, uint256 amount);
    event Retracted(address recipient, uint256 amount);

    // error AlreadySubscribed();
    error AlreadyStopped();
    // error InsufficientAmount(uint256 minimumAmount);
    error InsufficientBalance(uint256 availableBalance);
    error NotStarted();
    error UnAuthorized();

    constructor(address setProviderAddress, address tokAddress,
                address setUserAddress,
                uint256 setDayPrice) {
        tokToken = IERC20(tokAddress);
        dayPrice = setDayPrice;
        providerAddress = setProviderAddress;
        userAddress = setUserAddress;
    }

    function makeDeposit(uint256 amount) external nonReentrant {
        // if (userAddress != msg.sender) {
        //     revert AlreadySubscribed();
        // }

        // cannot wake up the service once it has stopped
        if (endTime != 0) {
            revert AlreadyStopped();
        }

        // allowance for the amount must have been approved by the sender
        tokToken.safeTransferFrom(msg.sender, address(this), amount);
        deposit += amount;

        // start contract on first deposit
        if (startTime == 0) {
            startTime = block.timestamp;
        }
        emit DepositMade(msg.sender, amount);
    }

    function stop() external nonReentrant {
        _stop(msg.sender);
    }

    function _stop(address from) private {
        if (! (from == userAddress || from == providerAddress)) {
            revert UnAuthorized();
        }
        if (endTime != 0) {
            revert AlreadyStopped();
        }

        endTime = block.timestamp;
        uint256 ticks = endTime - startTime;
        emit ServiceStopped(ticks);
    }

    function balanceUser() public view returns (uint256) {
        if (startTime == 0) {
            revert NotStarted();
        }
        if (msg.sender != userAddress) {
            revert UnAuthorized();
        }

        uint256 calcTime = endTime != 0 ? endTime : block.timestamp;
        uint256 duration = calcTime - startTime;
        uint256 paid = duration * dayPrice / 24 / 3600;

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
        uint256 balance = 0;
        uint256 bal1 = ticks * dayPrice / 24 / 3600;
        // cap the available balance
        if (bal1 > deposit - retracted) {
            balance = deposit - retracted;
        } else {
            balance = bal1;
        }
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

        tokToken.transfer(msg.sender, amount);
        deposit -= amount;
        emit Withdrawn(msg.sender, amount);

        // stop service?
        if (balance - amount <= dayPrice / 24 / 3600) {
            _stop(msg.sender);
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

        // stop service?
        if (deposit - retracted - amount < dayPrice / 24 / 3600) {
           _stop(msg.sender);
        }

        tokToken.transfer(msg.sender, amount);
        retracted += amount;
        emit Retracted(msg.sender, amount);
    }
}