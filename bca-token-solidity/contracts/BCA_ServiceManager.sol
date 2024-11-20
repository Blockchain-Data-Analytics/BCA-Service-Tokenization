// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Iface_ServiceManager.sol";
import "./BCA_ServiceController.sol";

// Factory contract that deploys controller contracts
contract BCAServiceManager is IServiceManager, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokToken;

    struct ControllerStruct {
        address addrContract;
        bool isDeployed;
    }
    mapping (address => ControllerStruct) public deployedControllers;
    address[] public providerControllers;
    
    // Event to notify when a new service is deployed
    event ControllerDeployed(address contractAddress);

    constructor(address tokAddress) {
        require(tokAddress != address(0), "Invalid token address");

        tokToken = IERC20(tokAddress);
    }

    function getControllerAddress(address providerAddress) public view returns(address addrController) {
        require (deployedControllers[providerAddress].isDeployed == true, "no controller for this provider");
        return deployedControllers[providerAddress].addrContract;
    }

    function isDeployed(address providerAddress) public view returns(bool isdeployed) {
        if (providerControllers.length == 0) return false;
        return (deployedControllers[providerAddress].isDeployed);
    }

    function newController(address providerAddress) external nonReentrant {
        require(! isDeployed(providerAddress), "already deployed controller for this provider");

        // Create a new SimpleContract
        BCAServiceController controllerContract = new BCAServiceController(providerAddress, address(tokToken));
        
        // Store the address
        providerControllers.push(providerAddress);
        deployedControllers[providerAddress].addrContract = address(controllerContract);
        deployedControllers[providerAddress].isDeployed = true;
        
        // Emit event
        emit ControllerDeployed(address(controllerContract));
    }

    function countServiceControllers() public view returns (uint) {
        return providerControllers.length;
    }
}