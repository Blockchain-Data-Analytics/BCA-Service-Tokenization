// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

interface IServiceManager {
        function newController(address providerAddress) external;
}