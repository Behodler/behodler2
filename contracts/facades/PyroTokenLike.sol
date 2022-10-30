// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
import "../openzeppelin/Ownable.sol";

abstract contract PyroTokenLike {

   address public baseToken;
    function redeem(uint256 pyroTokenAmount) external virtual returns (uint256);

    function mint(uint256 baseTokenAmount)
        external
        payable
        virtual
        returns (uint256);

    function redeemRate() public view virtual returns (uint256);

    // function baseToken() public view virtual returns (address);
}
