const { accounts, contract } = require("@openzeppelin/test-environment");
const {
  expectEvent,
  expectRevert,
  ether,
  balance,
} = require("@openzeppelin/test-helpers");
const { expect, assert } = require("chai");
const { BNtoBigInt } = require("./helpers/BigIntUtil");
const bigNum = require("./helpers/BigIntUtil");

const Behodler = contract.fromArtifact("Behodler");
const AddressBalanceCheck = contract.fromArtifact("AddressBalanceCheck");
const MockToken1 = contract.fromArtifact("MockToken1");
const Weth = contract.fromArtifact("WETH10");
const OpenArbiter = contract.fromArtifact("OpenArbiter");
const Lachesis = contract.fromArtifact("Lachesis");
const LiquidityReceiver = contract.fromArtifact("LiquidityReceiver");
const PyroToken = contract.fromArtifact("Pyrotoken");
const PyroWeth10Proxy = contract.fromArtifact("PyroWeth10Proxy");

const MockSwapFactory = contract.fromArtifact("MockSwapFactory");
const MockWeiDai = contract.fromArtifact("MockWeiDai");
const TEN = 10000000000000000000n;
const ONE = 1000000000000000000n;
const FINNEY = 1000000000000000n;

describe("Behodler1", async function () {
  const [owner, trader1, trader2, feeDestination, weiDaiReserve] = accounts;

  beforeEach(async function () {
    this.uniswap = await MockSwapFactory.new();
    this.sushiswap = await MockSwapFactory.new();

    const addressBalanceCheckLib = await AddressBalanceCheck.new();
    await Behodler.detectNetwork();
    await Behodler.link("AddressBalanceCheck", addressBalanceCheckLib.address);
    this.behodler = await Behodler.new({ from: owner });

    this.lachesis = await Lachesis.new(
      this.uniswap.address,
      this.sushiswap.address,
      { from: owner }
    );
    this.liquidityReceiver = await LiquidityReceiver.new(
      this.lachesis.address,
      { from: owner }
    );
    this.weth10 = await Weth.new({ from: owner });

    await this.lachesis.measure(this.weth10.address, true, false, {
      from: owner,
    });

    await this.liquidityReceiver.registerPyroToken(this.weth10.address, {
      from: owner,
    });
    const pyroTokenAddress = await this.liquidityReceiver.baseTokenMapping.call(
      this.weth10.address
    );
    this.pyroWeth10 = await PyroToken.at(pyroTokenAddress);
    this.pyroWeth10Proxy = await PyroWeth10Proxy.new(this.pyroWeth10.address, {
      from: owner,
    });
  });

  it("minting with zero eth fails. Minting with mismatched amount fails", async function () {
    await expectRevert(
      this.pyroWeth10Proxy.mint(0, { from: owner, value: 0 }),
      "PyroWethProxy: amount invariant"
    );

    await expectRevert(
      this.pyroWeth10Proxy.mint(100, { from: owner, value: 99 }),
      "PyroWethProxy: amount invariant"
    );
  });

  it("minting charges a 0.1% fee", async function () {
    const calculatedAmount = await this.pyroWeth10Proxy.calculateMintedPyroWeth(
      30000
    );
    await this.pyroWeth10Proxy.mint(30000, { from: owner, value: 30000 });

    expect(calculatedAmount.toString()).to.equal("29970");
    const pyroBalance = await this.pyroWeth10.balanceOf(owner);

    assert.equal(pyroBalance, "29970");
  });

  it("redeeming chargine a 1% fee", async function () {
    await this.pyroWeth10Proxy.mint(16000, { from: owner, value: 16000 });
    const pyroBalance = await this.pyroWeth10.balanceOf(owner);
    console.log("pyro Balance " + pyroBalance);
    const redeemRate = BigInt((await this.pyroWeth10.redeemRate()).toString());
    const weth10ValueOfPToken = (redeemRate * 15984n) / ONE;
    console.log("weth10 value " + weth10ValueOfPToken);
    const ethBalanceBefore = BigInt((await balance.current(owner)).toString());
    console.log("ethBalanceBefore " + ethBalanceBefore);
    await this.pyroWeth10.approve(
      this.pyroWeth10Proxy.address,
      "10000000000000000",
      { from: owner }
    );
    await this.pyroWeth10Proxy.redeem(15984, { from: owner });
    const ethBalanceAfter = BigInt((await balance.current(owner)).toString());
    const change = ethBalanceBefore - ethBalanceAfter;
    console.log("change " + change);
    const pyroBalanceAfter = await this.pyroWeth10.balanceOf(owner);
    assert.equal(pyroBalanceAfter.toString(), "0");

    console.log(
      "redeem rate after " + (await this.pyroWeth10.redeemRate()).toString()
    );
  });

  it("calculateRedeemedWeth", async function () {
    await this.pyroWeth10Proxy.mint(16000, { from: owner, value: 16000 });
    const pyroBalance = await this.pyroWeth10.balanceOf(owner);

    const redeemRate = BigInt((await this.pyroWeth10.redeemRate()).toString());

    await this.pyroWeth10.approve(
      this.pyroWeth10Proxy.address,
      "10000000000000000",
      { from: owner }
    );
    await this.pyroWeth10Proxy.redeem(10000, { from: owner });

    console.log(
      "pyroTokenSupply" + (await this.pyroWeth10.totalSupply()).toString()
    );
    console.log(
      " weth balance " + (await this.weth10.balanceOf(this.pyroWeth10.address))
    );

    const calculate = await this.pyroWeth10Proxy.calculateRedeemedWeth(2500);
    console.log("calculate " + calculate.toString()); //expect 2534
    assert.isTrue(calculate.toString() === "2534");
  });
});
