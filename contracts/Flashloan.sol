// SPDX-License-Identifier: MIT
pragma solidity ^0.7.1;

contract abstract FlashLoan {
    function execute () public virtual;
}