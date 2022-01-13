// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;
import "./Verifier.sol";

interface IDarkForest {
    function spwnPlayer(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[1] memory input) external;

    function move(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[2] memory input
    ) external;
}

contract DarkForest {
    struct TimestampData {
        uint val;
        bool isValue;
    }

    mapping(address => uint) public playerToLoc;
    mapping(uint => TimestampData) public spwnLocToTimestamp;
    mapping(uint => bool) public occupiedLoc;
    mapping(uint => uint) public planetLocToResource;
    mapping(address => uint) public playerToFinalResource;
    mapping(address => uint) public playerToTempResource;
    mapping(address => uint) public playerToLastMoveTimestamp;
    // mapping to store the location to the last player that came to that location.
    mapping(uint => address) public locToLastPlayer;

    IVerifier verifier;

    constructor (address _verifier) public {
        verifier = IVerifier(_verifier);
    }

    function spwnPlayer(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[1] memory input) public returns (bool) {
        uint spawnedLoc = input[0];
        bool isValid = verifier.verifySpwnProof(a, b, c, input);
        require (isValid, "incorrect spwn location");
        bool isAtAnotherPlayerRecentSpwnLocation = spwnLocToTimestamp[spawnedLoc].isValue
            && (spwnLocToTimestamp[spawnedLoc].val - block.timestamp) <= 5*60;
        require (!isAtAnotherPlayerRecentSpwnLocation, "can't spwn near another player's recent spwn location");
        bool isAtOccupiedLocation = occupiedLoc[spawnedLoc];
        require (!isAtOccupiedLocation, "can't spwn at occupied location");

        playerToLoc[msg.sender] = spawnedLoc;
        locToLastPlayer[spawnedLoc] = msg.sender;

        spwnLocToTimestamp[spawnedLoc] = TimestampData(block.timestamp, true);
        occupiedLoc[spawnedLoc] = true;

        return true;
    }

    function move(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[2] memory input
    ) public returns (bool) {
        bool isValid = verifier.verifyMoveProof(a, b, c, input);
        require (isValid, "incorrect target location");
        require (block.timestamp - playerToLastMoveTimestamp[msg.sender] > 30, "cannot move before 30s has lapsed.");
        uint targetLoc = input[1];
        uint oldLoc = playerToLoc[msg.sender];
        // only generate resource the first time the planet is occupied
        uint planetResource = 0;
        if (planetLocToResource[targetLoc] == 0) {
            planetResource = randomizeResourceAtLocation(targetLoc);
        }
        playerToLastMoveTimestamp[msg.sender] = block.timestamp;
        // if player moves to a different location from the last location, 
        // we will commit the resource to the player.
        if (targetLoc != oldLoc) {
            commitResource();
            playerToLoc[msg.sender] = targetLoc;
            // if the player moving out of a location is also the last player
            // coming to that location we remove the player from locationToLastPlayer
            if (locToLastPlayer[oldLoc] == msg.sender) {
                delete locToLastPlayer[oldLoc];
            }
        }
        
        // if no player is at the target loc, 
        // or if they want to move to the same location as the last move
        // then temporarily gather the resource at this location.
        if (locToLastPlayer[targetLoc] == address(0) || locToLastPlayer[targetLoc] == msg.sender) {
            gatherResource(targetLoc);
        } else {
            stealResource(targetLoc);
        }
        locToLastPlayer[targetLoc] = msg.sender;
    }

    function randomizeResourceAtLocation(uint location) internal returns (uint) {
        // check if the resource at a loc is zero. if it is, randomize a resource for that loc
        if (planetLocToResource[location] == 0) {
            
            // since 0 is the default value, we use that to mark that the resources
            // have not been initialized.
            // resources will be gathered as following
            // #1 = 0 unit of resource
            // #2 = 1 units of resource
            // #3 = 2 units of resource
            // #4 = 3 units of resource
            uint resource = block.timestamp % 3 + 1;
            planetLocToResource[location] = resource;
            return resource;
        }
        return 0;
    }

    function gatherResource(uint location) internal {
        playerToTempResource[msg.sender] += planetLocToResource[location] - 1;
    }

    function commitResource() internal {
        playerToFinalResource[msg.sender] += playerToTempResource[msg.sender];
        delete playerToTempResource[msg.sender];
    }

    function stealResource(uint location) internal {
        address lastPlayer = locToLastPlayer[location];
        playerToTempResource[msg.sender] = playerToTempResource[lastPlayer];
        playerToTempResource[lastPlayer] = 0;
    }
}

contract DFPlayer {
    IDarkForest darkForest;

    constructor (address _darkForest) public {
        darkForest = IDarkForest(_darkForest);
    }

    function submitSpwnPosition (
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[1] memory input) public {
        darkForest.spwnPlayer(a, b, c, input);
    }

    function moveToNewPosition (
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[2] memory input) public {
        darkForest.move(a, b, c, input);
    }
}