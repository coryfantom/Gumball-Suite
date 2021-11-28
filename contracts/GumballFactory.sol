// SPDX-License-Identifier: MIT
// Welcome to the Gumball Factory

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GumballMachine.sol";
import "./GoldenGumballMachine.sol";
import "./GumballMachineRegistry.sol";

contract GumballFactory is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    GumballMachineRegistry public gumballmachineregistry;

    function deployNewGumballMachine(address _payToken) public {
        address _deployedMachine = address(
            new GumballMachine(_msgSender(), _payToken)
        );

        gumballmachineregistry.addMachine(_msgSender(), _deployedMachine);
    }

    function deployNewGoldenGumballMachine(address _payToken) public {
        address _deployedMachine = address(
            new GoldenGumballMachine(_msgSender(), _payToken)
        );

        gumballmachineregistry.addMachine(_msgSender(), _deployedMachine);
    }

    function updateRegistryAddress(address _address) public onlyOwner {
        gumballmachineregistry = GumballMachineRegistry(_address);
    }
}