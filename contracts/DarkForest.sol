// SPDX-License-Identifier: MIT

pragma solidity ^0.6.11;
import "./Verifier.sol";

interface IDarkForest {
    function spwnPlanet(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[1] memory input) external;
}

contract DarkForest {
    struct TimestampData {
        uint val;
        bool isValue;
    }

    mapping(address => uint) public playerToLoc;
    mapping(uint => TimestampData) public spwnLocToTimestamp;
    mapping(uint => bool) public occupiedLoc;

    IVerifier verifier;

    constructor (address _verifier) public {
        verifier = IVerifier(_verifier);
    }

    function spwnPlanet(
        uint[2] memory a,
        uint[2][2] memory b,
        uint[2] memory c,
        uint[1] memory input) public returns (bool) {
        bool isValid = verifier.verifyProof(a, b, c, input);
        require (isValid, "incorrect spwn location");
        bool isAtAnotherPlayerRecentSpwnLocation = spwnLocToTimestamp[input[0]].isValue 
            && (spwnLocToTimestamp[input[0]].val - block.timestamp) <= 5*60;
        require (!isAtAnotherPlayerRecentSpwnLocation, "can't spwn near another player's recent spwn location");
        bool isAtOccupiedLocation = occupiedLoc[input[0]];
        require (!isAtOccupiedLocation, "can't spwn at occupied location");

        playerToLoc[msg.sender] = input[0];
        spwnLocToTimestamp[input[0]] = TimestampData(block.timestamp, true);
        occupiedLoc[input[0]] = true;
        return true;
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
        darkForest.spwnPlanet(a, b, c, input);
    }
}