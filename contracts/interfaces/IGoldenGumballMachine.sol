// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGoldenGumballMachine {

    function addGumball(address _nftAddress, uint256 _nftId) external;

    function insertGumballToken(uint256 _nftId) external;

    function enterDrawing() external;

    function beginDrawing() external;

    function fixStaleDrawing() external;

    function returnToken() external;

    function fixStatus() external;

    function pickTheWinner() external;

    function shuffleTickets() external;

    function crankTheLever() external;

    function revealYourGumball() external;

    event GumballAdded(
        address indexed owner,
        address indexed nftAddress,
        uint256 indexed nftId
    );

    event GumballClaimed(
        address indexed nftAddress,
        uint256 indexed nftId
    );

}