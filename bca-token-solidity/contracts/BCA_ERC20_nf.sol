// SPDX-License-Identifier: GPL-3.0
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
     * @param setName The name of the token.
     * @param setSymbol The symbol of the token.
     * @param setMinter The address that will be granted the minter role.
     * @param setBurner The address that will be granted the burner role.
     */
    constructor(string memory setName, string memory setSymbol, address setMinter, address setBurner)
        ERC20(setName, setSymbol)
    {
        serviceAddress = msg.sender;
        minterAddress = setMinter;
        burnerAddress = setBurner;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, setMinter);
        _grantRole(BURNER_ROLE, setBurner);
    }

    /**
     * @dev Allows the admin to set the service address.
     * @param newServiceAddress The address to set as the service address.
     */
    function setServiceAddress(address newServiceAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(DEFAULT_ADMIN_ROLE, serviceAddress);
        serviceAddress = newServiceAddress;
        _grantRole(DEFAULT_ADMIN_ROLE, newServiceAddress);
    }

    /**
     * @dev Allows the admin to set the minter address.
     * @param newMinterAddress The address to set as the minter address.
     */
    function setMinterAddress(address newMinterAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(MINTER_ROLE, minterAddress);
        minterAddress = newMinterAddress;
        _grantRole(MINTER_ROLE, newMinterAddress);
    }

    /**
     * @dev Allows the admin to set the burner address.
     * @param newBurnerAddress The address to set as the burner address.
     */
    function setBurnerAddress(address newBurnerAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _revokeRole(BURNER_ROLE, burnerAddress);
        burnerAddress = newBurnerAddress;
        _grantRole(BURNER_ROLE, newBurnerAddress);
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
        require(from == serviceAddress, "Burning only allowed on service account");
        _burn(from, amount);
    }
}