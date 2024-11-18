// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Iface_Funding24.sol";
import "./Iface_ServiceInstance.sol";

contract BCAServiceFunding24 is IFunding24, Ownable {
    using SafeERC20 for IERC20;

    address public immutable targetContract;
    uint256 public immutable dailyAmount;
    IERC20 public immutable token;
    uint256 public lastDepositTime;

    event DepositMade(address targetContract, uint256 amount, uint256 timestamp);

    constructor(
        address initialOwner,
        address setTargetContract,
        address setToken,
        uint256 setDailyAmount
    ) Ownable(initialOwner) {
        require(setTargetContract != address(0), "Invalid target contract address");
        require(setToken != address(0), "Invalid token address");
        require(setDailyAmount > 0, "Invalid daily amount");
        
        targetContract = setTargetContract;
        token = IERC20(setToken);
        dailyAmount = setDailyAmount;
        lastDepositTime = 0;
    }

    function deposit() external {
        require(
            lastDepositTime == 0 || block.timestamp >= lastDepositTime + 24 hours,
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
        token.safeTransferFrom(owner(), address(this), dailyAmount);

        // Set allowance for the target contract
        token.approve(targetContract, dailyAmount);
        
        try IServiceInstance(targetContract).makeDeposit(dailyAmount) {
            lastDepositTime = block.timestamp;
            emit DepositMade(targetContract, dailyAmount, block.timestamp);
        } catch Error(string memory reason) {
            revert(reason);
        } catch (bytes memory) {
            revert("failed to make deposit");
        }
    }

    // Function to check if deposit is currently possible
    function canDeposit() external view returns (bool) {
        return (lastDepositTime == 0 || block.timestamp >= lastDepositTime + 24 hours) &&
               token.balanceOf(owner()) >= dailyAmount &&
               token.allowance(owner(), address(this)) >= dailyAmount;
    }
}