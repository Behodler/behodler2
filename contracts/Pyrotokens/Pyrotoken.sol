// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "../openzeppelin/IERC20.sol";
import "../openzeppelin/SafeMath.sol";

abstract contract LiquidityReceiverFacade{
   function drain(address pyroToken) public virtual;
}

abstract contract ERC20MetaData {
    function symbol() public virtual returns (string memory);

    function name() public virtual returns (string memory);
}

contract Pyrotoken is IERC20 {
    event Mint(
        address minter,
        address baseToken,
        address pyroToken,
        uint256 redeemRate
    );
    event Redeem(
        address redeemer,
        address baseToken,
        address pyroToken,
        uint256 redeemRate
    );

    using SafeMath for uint256;
    uint256 _totalSupply;
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowances;
    address public baseToken;
    uint256 constant ONE = 1e18;
    LiquidityReceiverFacade liquidityReceiver;

    constructor(address _baseToken, address _liquidityReceiver) {
        baseToken = _baseToken;
        name = string(
            abi.encodePacked("Pyro", ERC20MetaData(baseToken).name())
        );
        symbol = string(
            abi.encodePacked("p", ERC20MetaData(baseToken).symbol())
        );
        decimals = 18;
        liquidityReceiver = LiquidityReceiverFacade(_liquidityReceiver);
    }

    string public override name;
    string public override symbol;
    uint8 public override decimals;

    modifier updateReserve {
        liquidityReceiver.drain(address(this));
        _;
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        external
        view
        override
        returns (uint256)
    {
        return balances[account];
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        external
        override
        returns (bool)
    {
        allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        require(
            allowances[sender][recipient] >= amount,
            "ERC20: not approved to send"
        );
        _transfer(sender, recipient, amount);
        return true;
    }

    function mint(uint256 baseTokenAmount) external updateReserve returns (uint) {
        uint256 rate = redeemRate();
        uint256 pyroTokensToMint = baseTokenAmount.mul(ONE).div(rate);
        require(
            IERC20(baseToken).transferFrom(
                msg.sender,
                address(this),
                baseTokenAmount
            ),
            "PYROTOKEN: baseToken transfer failed."
        );
        mint(msg.sender, pyroTokensToMint);
        emit Mint(msg.sender, baseToken, address(this), rate);
        return pyroTokensToMint;
    }

    function redeem(uint256 pyroTokenAmount) external updateReserve returns (uint) {
        //no approval necessary
        balances[msg.sender] = balances[msg.sender].sub(
            pyroTokenAmount,
            "PYROTOKEN: insufficient balance"
        );
        uint256 rate = redeemRate();
        _totalSupply = _totalSupply.sub(pyroTokenAmount);
        uint256 exitFee = pyroTokenAmount.mul(2).div(100); //2% burn on exit pushes up price for remaining hodlers
        uint256 net = pyroTokenAmount.sub(exitFee);
        uint256 baseTokensToRelease = rate.mul(net).div(ONE);
        IERC20(baseToken).transfer(msg.sender, baseTokensToRelease);
        emit Redeem(msg.sender, baseToken, address(this), rate);
        return baseTokensToRelease;
    }

    function redeemRate() public view returns (uint256) {
        uint256 balanceOfBase = IERC20(baseToken).balanceOf(address(this));
        if (_totalSupply == 0 || balanceOfBase == 0) return ONE;

        return balanceOfBase.mul(ONE).div(_totalSupply);
    }

    function mint(address recipient, uint256 amount) internal {
        balances[recipient] = balances[recipient].add(amount);
        _totalSupply = _totalSupply.add(amount);
    }

    function burn(uint256 amount) public {
        balances[msg.sender] = balances[msg.sender].sub(amount);
        _totalSupply = _totalSupply.sub(amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        uint256 burnFee = amount.div(1000); //0.1%
        balances[recipient] = balances[recipient].add(amount - burnFee);
        balances[sender] = balances[sender].sub(amount);
        _totalSupply = _totalSupply.sub(burnFee);
        emit Transfer(sender, recipient, amount);
    }
}
