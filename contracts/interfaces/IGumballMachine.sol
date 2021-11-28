// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGumballMachine {

    function addGumball(address _nftAddress, uint256 _nftId) external;

    function getBasicGumballTokens() external;

    function getDealGumballTokens() external;

    function returnToken() external;

    function fixStatus() external;

    function insertGumballToken() external;

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

    event GumMinted(
        address indexed owner,
        uint256 indexed amount
    );

}