// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

interface IService {
        function newInstance(address _userAddress) external returns (address);
}