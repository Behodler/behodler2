// File: contracts/flashLoans/FlashLoanArbiter.sol

// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

abstract contract FlashLoanArbiter {
    function canBorrow (address borrower) public virtual returns (bool);
}

//stand in until a better scheme enabled.
contract OpenArbiter is FlashLoanArbiter{
    function canBorrow (address borrower) public pure override returns (bool){
        return true;
    }
}
