// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

interface Iface_ServiceManager {
        function newService(uint16 _maxInstances, uint256 _dayPrice) external returns (address);
}