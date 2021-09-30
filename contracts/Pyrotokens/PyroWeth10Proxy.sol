// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
import "../facades/PyroTokenLike.sol";
import "../openzeppelin/Ownable.sol";
import "../WETH10.sol";
import "../openzeppelin/IERC20.sol";

contract PyroWeth10Proxy is Ownable, PyroTokenLike {
    // address public baseToken;
    IWETH10 public weth10;
    uint256 constant ONE = 1e18;

    constructor(address pyroWeth) {
        baseToken = pyroWeth;
        weth10 = IWETH10(PyroTokenLike(baseToken).baseToken());
        IERC20(weth10).approve(baseToken, uint256(-1));
    }

    function balanceOf(address holder) external view returns (uint256) {
        return IERC20(baseToken).balanceOf(holder);
    }

    function redeem(uint256 pyroTokenAmount)
        external
        override
        returns (uint256)
    {
        IERC20(baseToken).transferFrom(
            msg.sender,
            address(this),
            pyroTokenAmount
        ); //0.1% fee
        uint256 actualAmount = IERC20(baseToken).balanceOf(address(this));
        PyroTokenLike(baseToken).redeem(actualAmount);
        uint256 balanceOfWeth = weth10.balanceOf(address(this));
        weth10.withdrawTo(msg.sender, balanceOfWeth);
        return balanceOfWeth;
    }

    function mint(uint256 baseTokenAmount)
        external
        payable
        override
        returns (uint256)
    {
        require(
            msg.value == baseTokenAmount && baseTokenAmount > 0,
            "PyroWethProxy: amount invariant"
        );
        weth10.deposit{value: msg.value}();
        uint256 weth10Balance = weth10.balanceOf(address(this));
        PyroTokenLike(baseToken).mint(weth10Balance);
        uint256 pyroWethBalance = IERC20(baseToken).balanceOf(address(this));
        IERC20(baseToken).transfer(msg.sender, pyroWethBalance);
        return (pyroWethBalance * 999) / 1000; //0.1% fee
    }

    function calculateMintedPyroWeth(uint256 baseTokenAmount)
        external
        view
        returns (uint256)
    {
        uint256 pyroTokenRedeemRate = PyroTokenLike(baseToken).redeemRate();
        uint256 mintedPyroTokens = (baseTokenAmount * pyroTokenRedeemRate) /
            (ONE);
        return (mintedPyroTokens * 999) / 1000; //0.1% fee
    }

    function calculateRedeemedWeth(uint256 pyroTokenAmount)
        external
        view
        returns (uint256)
    {
        uint256 pyroTokenSupply = IERC20(baseToken).totalSupply() -
            ((pyroTokenAmount * 1) / 1000);
        uint256 wethBalance = IERC20(weth10).balanceOf(baseToken);
        uint256 newRedeemRate = (wethBalance * ONE) / pyroTokenSupply;
        uint256 newPyroTokenbalance = (pyroTokenAmount * 999) / 1000;
        uint256 fee = (newPyroTokenbalance * 2) / 100;
        uint256 net = newPyroTokenbalance - fee;
        return (net * newRedeemRate) / ONE;
    }

    function redeemRate() public view override returns (uint256) {
        return PyroTokenLike(baseToken).redeemRate();
    }
}
