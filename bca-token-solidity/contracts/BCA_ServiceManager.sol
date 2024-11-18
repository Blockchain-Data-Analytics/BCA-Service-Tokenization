// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./Iface_ServiceManager.sol";
import "./BCA_Service.sol";

// Factory contract that deploys service contracts
contract BCAServiceManager is Iface_ServiceManager, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokToken;
    address public immutable providerAddress;
    address[] public deployedServices;
    
    // Event to notify when a new service is deployed
    event ServiceDeployed(address contractAddress);

    constructor(address _providerAddress, address _tokAddress) {
        tokToken = IERC20(_tokAddress);
        providerAddress = _providerAddress;
    }

    function newService(uint16 _maxInstances, uint256 _dayPrice) external nonReentrant returns (address) {
        // Create a new SimpleContract
        BCAService serviceContract = new BCAService(providerAddress, address(tokToken), _maxInstances, _dayPrice);
        
        // Store the address
        deployedServices.push(address(serviceContract));
        
        // Emit event
        emit ServiceDeployed(address(serviceContract));
        
        return address(serviceContract);
    }
    
    function countServiceContracts() public view returns (uint) {
        return deployedServices.length;
    }
}