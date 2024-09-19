// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BCAServiceToken is ERC20, AccessControl {
    address public serviceAddress;
    address public minterAddress;
    address public burnerAddress;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @dev Constructor that sets up roles and gives the deployer the default admin role.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param minter The address that will be granted the minter role.
     * @param burner The address that will be granted the burner role.
     */
    constructor(string memory name, string memory symbol, address minter, address burner)
        ERC20(name, symbol)
    {
        serviceAddress = msg.sender;
        minterAddress = minter;
        burnerAddress = burner;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(BURNER_ROLE, burner);
    }

    /**
     * @dev Allows the admin to set the service address.
     * @param new_serviceAddress The address to set as the service address.
     */
    function setServiceAddress(address new_serviceAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DEFAULT_ADMIN_ROLE, serviceAddress);
        serviceAddress = new_serviceAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, new_serviceAddress);
    }

    /**
     * @dev Allows the admin to set the minter address.
     * @param new_minterAddress The address to set as the minter address.
     */
    function setMinterAddress(address new_minterAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, minterAddress);
        minterAddress = new_minterAddress;
        _grantRole(MINTER_ROLE, new_minterAddress);
    }

    /**
     * @dev Allows the admin to set the burner address.
     * @param new_burnerAddress The address to set as the burner address.
     */
    function setBurnerAddress(address new_burnerAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(BURNER_ROLE, burnerAddress);
        burnerAddress = new_burnerAddress;
        _grantRole(BURNER_ROLE, new_burnerAddress);
    }

    /**
     * @dev Mints new tokens. Can only be called by addresses with the MINTER_ROLE.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens. Can only be called by addresses with the BURNER_ROLE.
     * @param from The address from which to burn tokens.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    /**
     * @dev Overrides the transfer function to only allow transfers to the service address.
     * @param recipient The address to transfer tokens to (must be the service address).
     * @param amount The amount of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(recipient == serviceAddress, "Transfer only allowed to service address");
        return super.transfer(recipient, amount);
    }

    /**
     * @dev Overrides the transferFrom function to only allowance to the service address.
     * @param sender The address to transfer tokens from.
     * @param recipient The address to transfer tokens to (must be the service address).
     * @param amount The amount of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        require(recipient == serviceAddress, "Transfer only allowed to service address");
        return super.transferFrom(sender, recipient, amount);
    }
}