// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BCAServiceFunding24 is Ownable {
    address public immutable targetContract;
    uint256 public immutable dailyAmount;
    uint256 public lastDepositTime;
    IERC20 public immutable token;

    event DepositMade(uint256 amount, uint256 timestamp);

    constructor(
        address _initialOwner,
        address _targetContract,
        address _token,
        uint256 _dailyAmount
    ) Ownable(_initialOwner) {
        require(_targetContract != address(0), "Invalid target contract address");
        require(_token != address(0), "Invalid token address");
        require(_dailyAmount > 0, "Invalid daily amount");
        
        targetContract = _targetContract;
        token = IERC20(_token);
        dailyAmount = _dailyAmount;
    }

    function deposit() external {
        require(
            block.timestamp >= lastDepositTime + 24 hours,
            "24 hours have not passed since last deposit"
        );
        
        // Check if owner has sufficient balance and has approved this contract
        require(
            token.balanceOf(owner()) >= dailyAmount,
            "Insufficient balance in owner's wallet"
        );
        require(
            token.allowance(owner(), address(this)) >= dailyAmount,
            "Insufficient allowance from owner"
        );

        // Transfer tokens from owner to this contract
        token.transferFrom(owner(), address(this), dailyAmount);

        // Set allowance for the target contract
        token.approve(targetContract, dailyAmount);
        
        // Call deposit function on target contract
        (bool success, ) = targetContract.call(
            abi.encodeWithSignature("makeDeposit(uint256)", dailyAmount)
        );
        require(success, "Deposit failed");

        lastDepositTime = block.timestamp;
        
        emit DepositMade(dailyAmount, block.timestamp);
    }

    // Function to check if deposit is currently possible
    function canDeposit() external view returns (bool) {
        return block.timestamp >= lastDepositTime + 24 hours &&
               token.balanceOf(owner()) >= dailyAmount &&
               token.allowance(owner(), address(this)) >= dailyAmount;
    }
}