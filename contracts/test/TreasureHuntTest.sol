// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "../TreasureHunt.sol";

contract TreasureHuntTest is TreasureHunt {
    constructor(uint subscriptionId, address vrfCoordinator) TreasureHunt(subscriptionId, vrfCoordinator) {
    }

    function _findDestination(uint8 _currentPosition, Move _move) internal pure returns (uint8) {
        return findDestination(_currentPosition, _move);
    }

    function _moveTreasureToRandom() public {
        moveTreasureToRandom();
    }

    function _moveTreasureToAdjacent() public {
        moveTreasureToAdjacent();
    }

    function _sendPrize(address _winner) public {
        sendPrize(_winner);
    }

}