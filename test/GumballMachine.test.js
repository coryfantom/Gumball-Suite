// test/GumballMachine.test.js
// Load dependencies
const hre = require("hardhat");
const chai = require("chai");
const { 
  solidity 
} = require("ethereum-waffle");
chai.use(solidity);
const { 
  expect 
} = chai;

const { 
  expectRevert,
  time
} = require('@openzeppelin/test-helpers');

const { 
  ethers
} = require('hardhat');

const { 
  BigNumber
} = require('ethers');

describe("GumballMachine", function () {
  this.timeout(60000);

  // Set global variables
  const ZERO = new BigNumber.from("0");
  const ONE = new BigNumber.from("1");
  const TWO = new BigNumber.from("2");
  const THREE = new BigNumber.from("3");
  const FOUR = new BigNumber.from("4");
  const FIVE = new BigNumber.from("5");
  const SIX = new BigNumber.from("6");
  const SEVEN = new BigNumber.from("7");
  const EIGHT = new BigNumber.from("8");
  const NINE = new BigNumber.from("9");
  let BLOCK_NUM = new BigNumber.from("0");

  const INITIAL_TOKEN_AMOUNT = new BigNumber.from("10000000000000000000000");

  // Constants for the Gumball machine
  const GUMBALL_MACHINE_PRICE = new BigNumber.from("1000000000000000000");
  const MACHINE_ACTIVATE_REQUIREMENT = new BigNumber.from("10");
  const MACHINE_DEACTIVATE_REQUIREMENT = new BigNumber.from("2");
  const MAX_BLOCKS = new BigNumber.from("250");
  const BLOCK_BUFFER = new BigNumber.from("1");

  // Constants for the GUM exchange rate
  const BASIC_EXCHANGE_FROM = new BigNumber.from("1000000000000000000");
  const BASIC_EXCHANGE_TO = new BigNumber.from("2000000000000000000");
  const DEAL_EXCHANGE_FROM = new BigNumber.from("2000000000000000000");
  const DEAL_EXCHANGE_TO = new BigNumber.from("5000000000000000000");

  let MockERC20;
  let mockerc20;

  let MockERC721;
  let mockerc721;

  let GumballMachine;
  let gumballmachine;

  let owner;
  let contributor;
  let buyer;
  let other;

  afterEach(async function() {
    
  });

  beforeEach(async function () {

    // Deploy contracts used in the test
    MockERC20 = await ethers.getContractFactory("MockERC20");
    mockerc20 = await MockERC20.deploy();
    await mockerc20.deployed();
    MockERC721 = await ethers.getContractFactory("MockERC721");
    mockerc721 = await MockERC721.deploy();
    await mockerc721.deployed();
    GumballMachine = await ethers.getContractFactory("GumballMachine");
    gumballmachine = await GumballMachine.deploy(mockerc20.address);
    await gumballmachine.deployed();
    console.log("MockERC20 deployed to: " + mockerc20.address);
    console.log("MockERC721 deployed to: " + mockerc721.address);
    console.log("GumballMachine deployed to: " + gumballmachine.address);

    // Initiate users in the test
    [owner, contributor, buyer, other] = await ethers.getSigners();

    console.log("Owner: " + owner.address);
    console.log("Contributor: " + contributor.address);
    console.log("Buyer: " + buyer.address);
    console.log("Other: "+ other.address);

    // Sets the Mock ERC20 balance of users to `INITIAL_TOKEN_AMOUNT`
    await mockerc20.connect(owner).mint(owner.address, INITIAL_TOKEN_AMOUNT);
    await mockerc20.connect(contributor).mint(contributor.address, INITIAL_TOKEN_AMOUNT);
    await mockerc20.connect(buyer).mint(buyer.address, INITIAL_TOKEN_AMOUNT);
    await mockerc20.connect(other).mint(other.address, INITIAL_TOKEN_AMOUNT);

    await mockerc20.connect(owner).approve(
      gumballmachine.address,
      INITIAL_TOKEN_AMOUNT
    );

    await mockerc20.connect(contributor).approve(
      gumballmachine.address,
      INITIAL_TOKEN_AMOUNT
    );

    await mockerc20.connect(buyer).approve(
      gumballmachine.address,
      INITIAL_TOKEN_AMOUNT
    );

    await mockerc20.connect(other).approve(
      gumballmachine.address,
      INITIAL_TOKEN_AMOUNT
    );

    // Mint user `contributor` 100 Mock NFT's
    for (let i = 0; i <= 100; i++) {
      await mockerc721.connect(contributor).mint(contributor.address);
    }

    // Set approvals for the MockERC721 and MockERC20 tokens to the `GumballMachine.sol` contract
    await mockerc721.connect(owner).setApprovalForAll(
      gumballmachine.address,
      true
    );

    await mockerc721.connect(contributor).setApprovalForAll(
      gumballmachine.address,
      true
    );

    await mockerc721.connect(buyer).setApprovalForAll(
      gumballmachine.address,
      true
    );

    await mockerc721.connect(other).setApprovalForAll(
      gumballmachine.address,
      true
    );

    // Add 100 Mock NFT's to the Gumball Machine by user `contributor`
    for (let i = 0; i <= 100; i++) {
      await gumballmachine.connect(contributor).addGumball(mockerc721.address, i);
    }

    await gumballmachine.connect(owner).approve(
      gumballmachine.address,
      INITIAL_TOKEN_AMOUNT
    );

    await gumballmachine.connect(contributor).approve(
      gumballmachine.address,
      INITIAL_TOKEN_AMOUNT
    );

    await gumballmachine.connect(buyer).approve(
      gumballmachine.address,
      INITIAL_TOKEN_AMOUNT
    );

    await gumballmachine.connect(other).approve(
      gumballmachine.address,
      INITIAL_TOKEN_AMOUNT
    );

    for (let i = 0; i < 100; i++) {
      await expect(
        gumballmachine.connect(owner).getBasicGumballTokens())
        .to.emit(gumballmachine, 'GumMinted')
        .withArgs(owner.address, BASIC_EXCHANGE_TO);
    }

    for (let i = 0; i < 100; i++) {
      await expect(
        gumballmachine.connect(contributor).getBasicGumballTokens())
        .to.emit(gumballmachine, 'GumMinted')
        .withArgs(contributor.address, BASIC_EXCHANGE_TO);
    }

    for (let i = 0; i < 100; i++) {
      await expect(
        gumballmachine.connect(buyer).getBasicGumballTokens())
        .to.emit(gumballmachine, 'GumMinted')
        .withArgs(buyer.address, BASIC_EXCHANGE_TO);
    }

    for (let i = 0; i < 100; i++) {
      await expect(
        gumballmachine.connect(other).getBasicGumballTokens())
        .to.emit(gumballmachine, 'GumMinted')
        .withArgs(other.address, BASIC_EXCHANGE_TO);
    }

});

  // Scenario #1: A fresh Gumball Machine contract is launched, 100 (set contributor to 100) Gumballs are already added into the machine.
  // This scenario will return results for what happens when one user people exchange MockERC20 tokens for GUM tokens
  // and use the Machine until `isMachineInitialized` is equal to `false`.
  it('Scenario #1 successfully run', async function () {
    for (let i = 0; i < 100; i++) {
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(buyer).insertGumballToken();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(buyer).crankTheLever();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(buyer).revealYourGumball();
      let lastGumball = await gumballmachine.connect(buyer).lastGumball();
      let totalGumballs = await gumballmachine.connect(buyer).totalGumballs();
      console.log("Random Number: " + (lastGumball.toString()));
      console.log("Total Gumballs Remaining: " + (totalGumballs.toString()));
    }
  });
  /*
  it('Successfully approved GumballMachine for INITIAL_TOKEN_AMOUNT', async function () {
    await gumballmachine.connect(buyer).approve(
      gumballmachine.address,
      INITIAL_TOKEN_AMOUNT
    );

   expect(await mockerc20.connect(buyer).allowance(
    buyer.address,
    gumballmachine.address)
  ).to.be.bignumber.equal(INITIAL_TOKEN_AMOUNT);
  });

  it('Successfully exchanged Mock ERC20 tokens for GUM', async function () {
    for (let i = 0; i < 25; i++) {
      await expect(
        gumballmachine.connect(buyer).getBasicGumballTokens())
        .to.emit(gumballmachine, 'GumMinted')
        .withArgs(buyer.address, BASIC_EXCHANGE_TO);
    }
  });

  it('Inserted Gumball token', async function () {
    await gumballmachine.connect(buyer).insertGumballToken();
  });

  it('Block advanced? - MINT', async function () {
    await mockerc20.connect(other).mint(other.address, INITIAL_TOKEN_AMOUNT);
  });

  it('Cranked the lever', async function () {
    await gumballmachine.connect(buyer).crankTheLever();
  });

  it('Block advanced? - MINT', async function () {
    await mockerc20.connect(other).mint(other.address, INITIAL_TOKEN_AMOUNT);
  });

  it('Gumball claimed', async function () {
    await gumballmachine.connect(buyer).revealYourGumball();
    const lastGumball = await gumballmachine.connect(buyer).lastGumball();
    console.log((await time.latestBlock()).toString());
    console.log((lastGumball.toString()));
  });
  */

  /* Scenario #2:
  it('Scenario #2 successfully run', async function () {
    for (let i = 0; i < 250; i++) {
      // Buyer
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(buyer).insertGumballToken();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(buyer).crankTheLever();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(buyer).revealYourGumball();
      let lastGumball = await gumballmachine.connect(buyer).lastGumball();
      let totalGumballs = await gumballmachine.connect(buyer).totalGumballs();
      console.log("Random Number: " + (lastGumball.toString()));
      console.log("Total Gumballs Remaining: " + (totalGumballs.toString()));

      // Other
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(other).insertGumballToken();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(other).crankTheLever();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(other).revealYourGumball();
      lastGumball = await gumballmachine.connect(other).lastGumball();
      totalGumballs = await gumballmachine.connect(other).totalGumballs();
      console.log("Random Number: " + (lastGumball.toString()));
      console.log("Total Gumballs Remaining: " + (totalGumballs.toString()));

      // Contributor
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(contributor).insertGumballToken();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(contributor).crankTheLever();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(contributor).revealYourGumball();
      lastGumball = await gumballmachine.connect(contributor).lastGumball();
      totalGumballs = await gumballmachine.connect(contributor).totalGumballs();
      console.log("Random Number: " + (lastGumball.toString()));
      console.log("Total Gumballs Remaining: " + (totalGumballs.toString()));

      // Owner
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(owner).insertGumballToken();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(owner).crankTheLever();
      await time.advanceBlock();
      await time.advanceBlock();
      BLOCK_NUM = new BigNumber.from(Number(await time.latestBlock()));
      //console.log((BLOCK_NUM).toString());
      await gumballmachine.connect(owner).setBlockNum(BLOCK_NUM);
      await gumballmachine.connect(owner).revealYourGumball();
      lastGumball = await gumballmachine.connect(owner).lastGumball();
      totalGumballs = await gumballmachine.connect(owner).totalGumballs();
      console.log("Random Number: " + (lastGumball.toString()));
      console.log("Total Gumballs Remaining: " + (totalGumballs.toString()));
    }
  });
  */

});