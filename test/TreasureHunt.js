const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { networkConfig, developmentChains } = require("../helper-hardhat-config")
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("Lock", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployTreasureHuntFixture() {
      const [deployer] = await ethers.getSigners()
  
      const BASE_FEE = "1000000000000000" // 0.001 ether as base fee
      const GAS_PRICE = "50000000000" // 50 gwei 
      const WEI_PER_UNIT_LINK = "10000000000000000" // 0.01 ether per LINK

      const chainId = network.config.chainId

      const VRFCoordinatorV2_5MockFactory = await ethers.getContractFactory(
          "VRFCoordinatorV2_5Mock"
      )
      const VRFCoordinatorV2_5Mock = await VRFCoordinatorV2_5MockFactory.deploy(
        BASE_FEE,
        GAS_PRICE,
        WEI_PER_UNIT_LINK
      )
      await VRFCoordinatorV2_5Mock.waitForDeployment()
      const VRF_addr = await VRFCoordinatorV2_5Mock.getAddress();

      const fundAmount = networkConfig[chainId]["fundAmount"] || "1000000000000000000"
      const transaction = await VRFCoordinatorV2_5Mock.createSubscription()
      const transactionReceipt = await transaction.wait(1)
      const id = await VRFCoordinatorV2_5Mock.getActiveSubscriptionIds(0, 10)
      const subscriptionId = BigInt(id[0])
      await VRFCoordinatorV2_5Mock.fundSubscription(subscriptionId, fundAmount)

      const vrfCoordinatorAddress = VRFCoordinatorV2_5Mock.address
      const keyHash =
        networkConfig[chainId]["keyHash"] ||
        "0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc"

      const primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97];

      const treasureHuntFactory = await ethers.getContractFactory(
        "TreasureHuntTest"
      )

      const treasureHunt = await treasureHuntFactory
        .connect(deployer)
        .deploy(subscriptionId, VRF_addr)
      await treasureHunt.waitForDeployment();
      const treasureHuntAddress = await treasureHunt.getAddress()

      await VRFCoordinatorV2_5Mock.fundSubscriptionWithNative(subscriptionId, {value: ethers.parseUnits("1", "ether")})


      await VRFCoordinatorV2_5Mock.addConsumer(subscriptionId, treasureHuntAddress)

      return { treasureHunt, VRFCoordinatorV2_5Mock, treasureHuntAddress }
    }
  
    describe("Participate", function () {
      it("Should have primes", async function () {
        const { treasureHunt, VRFCoordinatorV2_5Mock, treasureHuntAddress } = await loadFixture(deployTreasureHuntFixture);
        const primes = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97];
        for (val of primes) {
            expect(await treasureHunt.primes(val)).to.equal(true);
        }
        const location = await treasureHunt.treasurePosition();
        expect(location).to.be.at.least(0);
        expect(location).to.be.at.most(99);
      });

      it("Should allow to participate", async function () {
        const { treasureHunt, VRFCoordinatorV2_5Mock, treasureHuntAddress } = await loadFixture(deployTreasureHuntFixture);
        const [owner, user1] = await ethers.getSigners();
        await treasureHunt.connect(user1).participate({value: ethers.parseUnits("1000000", "gwei")})
        expect(await treasureHunt.participants(user1.address)).to.equal(true);
        const playerLocation = await treasureHunt.playerPosition(user1.address);
        expect(playerLocation).to.be.at.least(0);
        expect(playerLocation).to.be.at.most(99);
      });

      it("Should allow player to move", async function () {
        const { treasureHunt, VRFCoordinatorV2_5Mock, treasureHuntAddress } = await loadFixture(deployTreasureHuntFixture);
        const [owner, user1] = await ethers.getSigners();
        await treasureHunt.connect(user1).participate({value: ethers.parseUnits("1000000", "gwei")})
        const playerLocationBefore = await treasureHunt.playerPosition(user1.address);
        await treasureHunt.connect(user1).makeMove(2);
        const playerLocationAfter = await treasureHunt.playerPosition(user1.address);
        if (playerLocationBefore == BigInt(0)) {
            expect(playerLocationAfter).to.equal(BigInt(99));
        } else {
            expect(playerLocationAfter).to.equal(playerLocationBefore-BigInt(1));
        }
      });

      it("Should not allow player if not participating", async function () {
        const { treasureHunt, VRFCoordinatorV2_5Mock, treasureHuntAddress } = await loadFixture(deployTreasureHuntFixture);
        const [owner, user1] = await ethers.getSigners();
        await expect(treasureHunt.connect(user1).makeMove(2)).to.be.revertedWith("Player has not entered the game");
      });
  
      it("Should move treasure randomly", async function () {
        const { treasureHunt, VRFCoordinatorV2_5Mock, treasureHuntAddress } = await loadFixture(deployTreasureHuntFixture);
        const [owner, user1] = await ethers.getSigners();
        await treasureHunt.connect(user1).participate({value: ethers.parseUnits("1000000", "gwei")})
        const treasureLocationBefore = await treasureHunt.treasurePosition();
        await treasureHunt._moveTreasureToRandom();
        const reqId = await treasureHunt.requestId();
        await VRFCoordinatorV2_5Mock.fulfillRandomWordsWithOverride(reqId, treasureHuntAddress, [1001]);
        const treasureLocationAfter = await treasureHunt.treasurePosition();
        expect(treasureLocationAfter).to.be.at.least(0)
        expect(treasureLocationAfter).to.be.at.most(99)
      });

      it("Should move treasure to adjacent location", async function () {
        const { treasureHunt, VRFCoordinatorV2_5Mock, treasureHuntAddress } = await loadFixture(deployTreasureHuntFixture);
        const [owner, user1] = await ethers.getSigners();
        await treasureHunt.connect(user1).participate({value: ethers.parseUnits("1000000", "gwei")})
        const treasureLocationBefore = await treasureHunt.treasurePosition();
        await treasureHunt._moveTreasureToAdjacent();
        const reqId = await treasureHunt.requestId();
        await VRFCoordinatorV2_5Mock.fulfillRandomWordsWithOverride(reqId, treasureHuntAddress, [3]);
        const treasureLocationAfter = await treasureHunt.treasurePosition();
        if (treasureLocationBefore != BigInt(99)) {
            expect(treasureLocationAfter).to.be.equal(treasureLocationBefore + BigInt(1))    
        }
      });

      it("Should distribute prize correctly", async function () {
        const { treasureHunt, VRFCoordinatorV2_5Mock, treasureHuntAddress } = await loadFixture(deployTreasureHuntFixture);
        const [owner, user1, user2, user3] = await ethers.getSigners();
        await treasureHunt.connect(user1).participate({value: ethers.parseUnits("1000000", "gwei")})
        await treasureHunt.connect(user2).participate({value: ethers.parseUnits("1000000", "gwei")})
        await treasureHunt.connect(user3).participate({value: ethers.parseUnits("1000000", "gwei")})
        
        const balanceContract = await ethers.provider.getBalance(treasureHuntAddress)
        const balanceBefore = await ethers.provider.getBalance(user1.address)
        await treasureHunt._sendPrize(user1.address);
        const balanceAfter = await ethers.provider.getBalance(user1.address)
        console.log(balanceAfter - balanceBefore)
        expect(balanceAfter - balanceBefore).to.be.equal((balanceContract*BigInt(9))/BigInt(10))
      });
    });
  });
  