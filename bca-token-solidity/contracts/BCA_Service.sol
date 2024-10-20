// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BCAServiceContract is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // the price for launching the contract; will remain with the contract
    // adjust for the various transaction costs depending on chain
    uint256 public constant setupFee = 2 * 10 ** 17;

    // will be set in the constructor
    IERC20 public immutable tokToken;
    uint256 public immutable dayPrice;
    address public immutable providerAddress;
    uint256 public deposit;
    uint256 public retracted;
    uint256 public startTime;
    uint256 public endTime;
    address public userAddress;

    event DepositMade(address user, uint256 amount);
    event ServiceStopped(uint256 ticks);
    event Withdrawn(address recipient, uint256 amount);
    event Retracted(address recipient, uint256 amount);

    error AlreadySubscribed();
    error AlreadyStopped();
    error InsufficientAmount(uint256 minimumAmount);
    error InsufficientBalance(uint256 availableBalance);
    error NotStarted();
    error UnAuthorized();

    constructor(address _providerAddress, address _tokAddress, uint256 _dayPrice) {
        tokToken = IERC20(_tokAddress);
        dayPrice = _dayPrice;
        providerAddress = _providerAddress;
    }

    function makeDeposit(uint256 amount) external nonReentrant {
        // require(amount > 0, "Deposit must be greater than 0"); by type!
        if (! (userAddress == address(0) || userAddress == msg.sender)) {
            revert AlreadySubscribed();
        }

        // first deposit pays the setup fee
        if (userAddress == address(0) && amount < (setupFee + (dayPrice / 24))) {
            revert InsufficientAmount(setupFee + (dayPrice / 24));
        }

        // cannot wake up the service once it has stopped
        if (endTime != 0) {
            revert AlreadyStopped();
        }

        // allowance for the amount must have been approved by the sender
        tokToken.safeTransferFrom(msg.sender, address(this), amount);
        deposit += amount;

        // remember user who made first deposit (e.g. subscribed)
        if (userAddress == address(0)) {
            userAddress = msg.sender;
            startTime = block.timestamp;
            deposit -= setupFee; // pay setup fee
        }
        emit DepositMade(msg.sender, amount);
    }

    function stop() external {
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
        if (userAddress == address(0) || startTime == 0) {
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

        deposit -= amount;
        tokToken.transfer(msg.sender, amount);
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

        retracted += amount;
        tokToken.transfer(msg.sender, amount);
        emit Retracted(msg.sender, amount);
    }
}