// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

abstract contract Context {
    function msgSender() internal view returns (address) {
        return msg.sender;
    }
}