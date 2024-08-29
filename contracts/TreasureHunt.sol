// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

// Uncomment this line to use console.log
// import "hardhat/console.sol";

/// @title Treasure Hunt Game
/// @author Vishnu
/// @notice A small treasure hunt game 
contract TreasureHunt is VRFConsumerBaseV2Plus {
    uint256 s_subscriptionId;
    address vrfCoordinator = 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B;
    bytes32 s_keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae;
    uint32 callbackGasLimit = 40000;
    uint16 requestConfirmations = 3;
    uint32 numWords =  1;

    enum Move {
        Up,
        Down,
        Left,
        Right
    }
    
    mapping(uint8 => bool) public primes;
    mapping(address => bool) public participants;
    mapping(address => uint8) public playerPosition;
    uint8 public treasurePosition;
    bool public isRandomGenerationInProgress;
    bool isRandom;
    uint public requestId;

    uint public constant ENTRY_FEE = 1000000 gwei;

    event ParticipantAdded(address user);
    event RandomnessRequested(uint256 indexed requestId);
    event RandomnessReceived(uint256 indexed requestId);
    event PrizeSent(address winner, uint amount);

    constructor(uint subscriptionId, uint8[] memory primeNums, address vrfCoordinator) VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_subscriptionId = subscriptionId;
        treasurePosition = uint8(uint(blockhash(block.number - 1)) % 100);
        isRandomGenerationInProgress = false;
        // Providing all prime numbers under 100 in an array
        for (uint i = 0; i < primeNums.length; i++) {
            primes[primeNums[i]] = true;
        }
    }

    /// @notice Function to be called by user to participate in the game by sending ETH
    function participate() public payable {
        require(msg.value == ENTRY_FEE, "Please send right amount of ETH");
        participants[msg.sender] = true;
        playerPosition[msg.sender] = uint8(uint(blockhash(block.number - 1)) % 100);
        emit ParticipantAdded(msg.sender);
    }

    /// @notice Function to be called by user to make a move
    /// @param _move one of the 4 values among up, down, left, right
    function makeMove(Move _move) public {
        // Treasure position update not complete according to the previous user's movement yet
        // Waiting for VRF callback
        require(!isRandomGenerationInProgress, "Last player's move is not complete");
        require(participants[msg.sender], "Player has not entered the game");
        uint8 newPosition = findDestination(playerPosition[msg.sender], _move);

        // If new position is treasure position, send prize amount to user and move treasure to new position
        if (treasurePosition == newPosition) {
            sendPrize(msg.sender);
            isRandom = true;
            requestRandomness();
            // Signal the system to wait for the treasure position update which happens after VRF callback
            isRandomGenerationInProgress = true;
        }

        playerPosition[msg.sender] = newPosition;

        // If new position is a multiple of 5, move treasure to random adjacent position
        if (newPosition % 5 == 0) {
            isRandom = false;
            requestRandomness();
            // Signal the system to wait for the treasure position update which happens after VRF callback
            isRandomGenerationInProgress = true;
        }

        // If new position is a prime number, move treasure to random position
        if (primes[newPosition] ==  true) {
            isRandom = true;
            requestRandomness();
            // Signal the system to wait for the treasure position update which happens after VRF callback
            isRandomGenerationInProgress = true;
        }

    }

    /// @notice Internal function to request randomness using Chainlink VRF
    function requestRandomness() internal {
        
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true}))
            })
        );

        emit RandomnessRequested(requestId);
    }

    /// @notice Function to be called by Chainlink to get random value
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint randomValue = randomWords[0];

        // Move treasure to random position in the grid
        if (isRandom) {
            treasurePosition = uint8(randomValue % 100);
        // Move treasure to one of the adjacent positions (up, down, left, right)
        } else {
            uint8 adjacentMovement = uint8(randomValue % 4);
            // Move up
            if (adjacentMovement == 0) {
                // If current position is first row, move to last row
                if (treasurePosition - 10 < 0) {
                    treasurePosition += 90;
                } else {
                    treasurePosition -= 10;
                }
            // Move down. If current position is last row, move to first row
            } else if (adjacentMovement == 1) {
                treasurePosition = (treasurePosition + 10) % 100;
            // Move left
            } else if (adjacentMovement == 2) {
                // If current position is grid 0, move to grid 99
                if (treasurePosition == 0) {
                    treasurePosition = 99;
                } else {
                    treasurePosition -= 1;
                }
            // Move right. If current position is grid 99, move to grid 0
            } else {
                treasurePosition = (treasurePosition + 1) % 100;
            }
        }

        isRandomGenerationInProgress = false;

        emit RandomnessReceived(requestId);
    }

    /// @notice Internal helper function to get new position of user according to the move
    /// @param _currentPosition current position of the user
    /// @param _move member of Move enum
    function findDestination(uint8 _currentPosition, Move _move) internal pure returns (uint8) {
        uint8 newPosition;
        if (_move == Move.Left) {
            if (_currentPosition == 0) {
                newPosition = 99;
            // If current position is grid 0, move to grid 99
            } else {
                newPosition = _currentPosition - 1; 
            }
        // If current position is grid 99, move to grid 0
        } else if (_move == Move.Right) {
            newPosition = (_currentPosition + 1) % 100; 
        } else if (_move == Move.Up) {
            // If current position is first row, move to last row
            if (_currentPosition - 10 < 0) {
                newPosition = _currentPosition + 90;
            } else {
                newPosition -= 10; 
            }
        // If current position is last row, move to first row
        } else {
            newPosition = (_currentPosition + 10) % 100;
        }

        return newPosition;
    }

    /// @notice Internal function to send prize amount in ETH to winner
    /// @param _winner address of the winner
    function sendPrize(address _winner) internal {
        uint balance = address(this).balance;
        uint prizeAmount = (balance * 9) / 10;
        (bool sent, bytes memory data) = _winner.call{value: prizeAmount}("");
        require(sent, "Failed to send Ether");
        emit PrizeSent(_winner, prizeAmount);
    }

    receive() external payable {
    }

    //////////////////////////
    // Functions for testing//
    //////////////////////////

    function moveTreasureToRandom() internal {
        isRandom = true;
        requestRandomness();
        // Signal the system to wait for the treasure position update which happens after VRF callback
        isRandomGenerationInProgress = true;
    }

    function moveTreasureToAdjacent() internal {
        isRandom = false;
        requestRandomness();
        // Signal the system to wait for the treasure position update which happens after VRF callback
        isRandomGenerationInProgress = true;
    }
}