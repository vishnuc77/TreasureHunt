# Treasure Hunt

A simple game in which participants can join by paying a small amount of ETH and on finding treasure. can win 90% of the contract value

## File Structure
Contract: contracts/TreasureHunt.sol
Test: test/TreasureHunt.js
Helper Contract for test: contract/test/*

## Tests

```shell
npx hardhat test
```
## Assumptions
- Amount to participate in the game: 1000000 gwei
- Initial position of treasure will be dependent on the last blockchash
- Initial position of a player will also be dependent on the last blockhash. Even if the initial position of player is same as treasure position, user is NOT declared as winner
- For testing purposes, have added a new helper contract named `TreasureHuntTest.sol`, which inherits the actual contract. This way all the internal functionalities can be tested.
- The following variables were made public for testing, these have to be made private before deployment to mainnet:
  ```shell
  playerPosition mapping
  treasurePosition value
  requestId value
  ```
- There are some internal functions as well implemented for testing, which have to removed. These are:
  ```shell
  moveTreasureToRandom()
  moveTreasureToAdjacent()
  ```
- When the player is in top row and player tries to move UP or treasure position is in top row and player movement triggered treasure movement to adjacent position and random value resulted in UP movememnt, it is assumed that the movement will happen to the last row
- When the player is in last row and player tries to move DOWN or treasure position is in last row and player movement triggered treasure movement to adjacent position and random value resulted in DOWN movememnt, it is assumed that the movement will happen to the first row
- Similarly LEFT movement from 0th grid movement will result in final position as 99th grid and RIGHT movement from 99th grid movement will result in final position as 0th grid


## Design Choices
- For the 10x10 grid, selected numbers from 0 to 99, in which 0-9 will be first row, 10-19 will be second row and so on. In this way we can avoid storing anything unnecessary.
- Up movement is grid-10, Down movement is grid+10, Left movement is grid-1 and Right movement is grid+1
- For each user input instead of checking programmatically whether the resulting new position is prime number, in constructor itself, for all prime numbers we set a mapping as true, which can later be used to check whether a number between 0 and 99 is prime or not.
- When user's new position is multiple of 5, treasure can move either move up, down, left or right, so we get random number from Chainlink VRF and do modulus 4 to get one of 4 values. Here 0 will mean UP, 1 will mean DOWN, 2 will mean left and 3 will mean RIGHT
- When user's new position is a prime number, we get a random number from Chainlink VRF and do modulus 100, so that we will get a random position in the grid.
- Between the random value is requested from Chainlink VRF and the callback is not reached to TreasureHunt contract yet, we do not allow new players to make a move. This will mean that only once the previous player's move is completely over, a new player can make a move, which ensures fairness.
- For testing, made use of a helper contract which inherits the actual contract and also made use of mock chainlink VRF contract, so that generation of random values can be tested. Achieved 100% functions coverage
