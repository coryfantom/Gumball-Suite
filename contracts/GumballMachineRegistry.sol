// SPDX-License-Identifier: MIT
// Welcome to the Gumball Machine Registry

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./GumballFactory.sol";

contract GumballMachineRegistry is Ownable {
    using SafeMath for uint256;

    address public factoryAddress;

    uint256 public TOTAL_GUMBALL_MACHINES;

    struct GumballMachines {
        address owner;
        address machineAddress;
    }

    mapping (uint256 => GumballMachines) public gumballMachines;

    function addMachine(address _owner, address _machineAddress) external onlyFactory {
        GumballMachines storage machine = gumballMachines[TOTAL_GUMBALL_MACHINES];
        machine.owner = _owner;
        machine.machineAddress = _machineAddress;
        TOTAL_GUMBALL_MACHINES++;
    }

    function updateFactoryAddress(address _address) external onlyOwner {
        factoryAddress = _address;
    }

    modifier onlyFactory() {
        require(
            _msgSender() == factoryAddress,
            "Only the factory can call this function"
        );
        _;
    }
}