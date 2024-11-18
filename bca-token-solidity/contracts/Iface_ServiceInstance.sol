// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

interface Iface_ServiceInstance {
        function makeDeposit(uint256 amount) external;
        function stop() external;
        function withdrawUser(uint256 amount) external;
        function withdrawProvider(uint256 amount) external;
}