// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Iface_Service.sol";
import "./BCA_ServiceInstance.sol";

contract BCAService is IService, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // will be set in the constructor
    IERC20 public immutable tokToken;
    uint256 public immutable dayPrice;
    address public immutable providerAddress;
    uint16 public immutable maxInstances;

    address[] public deployedInstances;

    // Event to notify when a new instance is deployed
    event InstanceDeployed(address contractAddress);

    error Exhausted();

    constructor(address setProviderAddress, address tokAddress, 
                uint16 setMaxInstances, uint256 setDayPrice) {
        tokToken = IERC20(tokAddress);
        dayPrice = setDayPrice;
        providerAddress = setProviderAddress;
        maxInstances = setMaxInstances;
    }

    function newInstance(address userAddress) external nonReentrant returns (address) {
        if (deployedInstances.length >= maxInstances) {
            revert Exhausted();
        }
        // Create a new SimpleContract
        BCAServiceInstance instanceContract = new BCAServiceInstance(providerAddress, address(tokToken), userAddress, dayPrice);
        
        // Store the address
        deployedInstances.push(address(instanceContract));
        
        // Emit event
        emit InstanceDeployed(address(instanceContract));
        
        return address(instanceContract);
    }

    function countServiceInstances() public view returns (uint) {
        return deployedInstances.length;
    }
}