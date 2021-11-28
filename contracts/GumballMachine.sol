// SPDX-License-Identifier: MIT
// Welcome to the Gumball Machine

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IGumballMachine.sol";

contract GumballMachine is 
    IGumballMachine, 
    ERC20, 
    ERC721Holder, 
    Ownable, 
    ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor (address _owner, address _payToken) ERC20("Gumball Tokens", "GUM") {
        GUM = IERC20(address(this));
        payToken = IERC20(_payToken);
        transferOwnership(_owner);
    }

    // STRUCTS, MAPPINGS, AND ARRAYS //
    
    // Parameters of Gumballers (shot callers, 20" blades, on the Impala)
    struct Gumballers {
        uint256 gumballerBlocknum;
        bool gumballerBool;
        bool honorBool;
    }
    
    // Parameters of Gumballs
    struct Gumballs {
        address nftAddress;
        uint256 nftId;
        address owner;
    }

    mapping(address => Gumballers) public gumballers;
    Gumballs[] public gumballs;

    // CONSTANTS AND GLOBAL VARIABLES //

    // ERC20 interfaces
    IERC20 public GUM;
    IERC20 public payToken;

    // Bool to ensure the machine has sufficient Gumballs inserted before allowing tokens to be inserted
    bool public isMachineInitialized;

    // Gumball Machine global variables
    uint256 public totalGumballs;
    uint256 public lastGumball;
    uint256 public blockNum;

    // Gumball Machine admin-set variables
    uint256 public GUMBALL_MACHINE_PRICE;
    uint256 public MACHINE_ACTIVATE_REQUIREMENT;
    uint256 public MACHINE_DEACTIVATE_REQUIREMENT;
    uint256 public BASIC_EXCHANGE_FROM;
    uint256 public BASIC_EXCHANGE_TO;
    uint256 public DEAL_EXCHANGE_FROM;
    uint256 public DEAL_EXCHANGE_TO;

    // Constants for the Gumball machine
    uint256 public constant MAX_BLOCKS = 250;
    uint256 public constant BLOCK_BUFFER = 1;

    // FUNCTION MODIFIERS //

    modifier onlyNotContract() {
        require(
            _msgSender() == tx.origin,
            "Only contracts can call this function"
        );
        _;
    }

    modifier gumballMachineActive() {
        require(
            isMachineInitialized == true,
            "Machine stock is too low to use, come back later when more Gumballs are added!"
            );
        _;
    }
    
    // ADMIN-ONLY FUNCTIONS //
    
    /**
     @notice Function to set the current ERC20 token to exchange for GUM
     @param _payToken ERC20 Address
     */
    function setPayToken(address _payToken) public onlyOwner {
        payToken = IERC20(_payToken);
    }

    function setMachinePrice(uint256 _price) public onlyOwner {
        GUMBALL_MACHINE_PRICE = _price;
    }

    function setActiveRequirements(uint256 _deactivate, uint256 _activate) public onlyOwner {
        MACHINE_DEACTIVATE_REQUIREMENT = _deactivate;
        MACHINE_ACTIVATE_REQUIREMENT = _activate;
    }

    function setBasicExchangeRate(uint256 _from, uint256 _to) public onlyOwner {
        BASIC_EXCHANGE_FROM = _from;
        BASIC_EXCHANGE_TO = _to;
    }

    function setDealExchangeRate(uint256 _from, uint256 _to) public onlyOwner {
        DEAL_EXCHANGE_FROM = _from;
        DEAL_EXCHANGE_TO = _to;
    }

    function setBlockNum(uint256 _blockNum) public {
        blockNum = _blockNum;
    }

    // EXTERNAL FUNCTIONS //

    /**
     @notice External function to add Gumballs to the machine
     @param _nftAddress ERC 721 Address
     @param _nftId NFT ID
     */
    function addGumball(address _nftAddress, uint256 _nftId) 
        external 
        override 
        nonReentrant 
    {
        // HARD CHECK: Requires sender to own the NFT
        require(
            IERC721(_nftAddress).ownerOf(_nftId) == _msgSender(),
            "You don't own this NFT"
        );

        // HARD CHECK: Requires Gumball contract to be approved
        require(
            IERC721(_nftAddress).isApprovedForAll(
                _msgSender(),
                address(this)
            ),
            "Gumball hasn't been approved"
        );

        // Call internal function _addGumball to complete the addGumBall process
        _addGumball(
            _nftAddress,
            _nftId
        );
    }

    /**
     @notice Exchanges ERC20 tokens for GUM (Gumball Tokens) (At basic exchange rate)
     */
    function getBasicGumballTokens()
        public
        override
        nonReentrant
        onlyNotContract
    {
        _getBasicGumballTokens(_msgSender(), BASIC_EXCHANGE_FROM);
    }

    function _getBasicGumballTokens(address _to, uint256 _amount) 
        internal 
    {
        // HARD CHECK: Requires the _msgSender() to have enough ERC20 tokens to transfer
        require(
                payToken.transferFrom(_to, address(this), _amount),
                "Insufficient balance or not approved"
        );
        // Mints your brand new Gumball tokens!
        _mint(
            _to, 
            BASIC_EXCHANGE_TO 
        );

        emit GumMinted(_to, _amount);
    }

    /**
     @notice Exchanges ERC20 tokens for GUM (Gumball Tokens) (At deal exchange rate)
     */
    function getDealGumballTokens()
        public
        override
        nonReentrant
        onlyNotContract
    {
        _getDealGumballTokens(_msgSender(), DEAL_EXCHANGE_FROM);
    }

    function _getDealGumballTokens(address _to, uint256 _amount) 
        internal 
    {
        // HARD CHECK: Requires the _msgSender() to have enough ERC20 tokens to transfer
        require(
                payToken.transferFrom(_to, address(this), _amount),
                "Insufficient balance or not approved"
        );
        // Mints your brand new Gumball tokens!
        _mint(
            _to, 
            DEAL_EXCHANGE_TO 
        );

        emit GumMinted(_to, _amount);
    }

    /**
     @notice Fixes stuck tokens (Tokens that were inserted and left before resulting)
     */
    function returnToken()
        public
        override
    {
        Gumballers storage gumballer = gumballers[_msgSender()];

        // HARD CHECK: Require the token be inserted before returning
        require(
              gumballer.gumballerBool == true &&
              gumballer.honorBool == false,
              "No token found"
        );

        // HARD CHECK: Require block.number to be greater than MAX_BLOCKS blocks from when the token was inserted
        require(
              block.number >= (gumballer.gumballerBlocknum + MAX_BLOCKS),
              "Token isn't stale"
        );

        // Returns GUM
        GUM.transferFrom(
            address(this),
            _msgSender(),
            GUMBALL_MACHINE_PRICE
        );
        
        gumballer.gumballerBool = false;
    }

    /**
     @notice Fixes account status in the event that a user inserted a token, cranked the lever, then waited longer than the allowed time
     */
    function fixStatus()
        public
        override
    {
        Gumballers storage gumballer = gumballers[_msgSender()];

        // HARD CHECK: Require a token be inserted before fixing
        require(
              gumballer.gumballerBool == true &&
              gumballer.honorBool == true,
              "No token found"
        );

        // HARD CHECK: Require block.number to be greater than MAX_BLOCKS blocks from when the lever was cranked
        require(
              block.number > (gumballer.gumballerBlocknum + MAX_BLOCKS),
              "Token hasn't expired yet"
        );
        
        gumballer.gumballerBool = false;
        gumballer.honorBool = false;
    }

    /**
     @notice Inserts GUM token into the machine
     */
    function insertGumballToken()
        public
        override
        nonReentrant
        onlyNotContract
        gumballMachineActive
    {
        Gumballers storage gumballer = gumballers[_msgSender()];
        
        // HARD CHECK: Require the sender has enough GUM tokens to use the machine
        require(
            IERC20(address(this)).balanceOf(
                _msgSender()) >= GUMBALL_MACHINE_PRICE,
                "Insufficient Gumball Token balance"
        );
        
        // HARD CHECK: Require no current Gumball purchase in queue
        require(
              gumballer.gumballerBool == false,
              "Gumball already purchased"
        );

        // Inserts GUM token into the machine
        GUM.transferFrom(
            _msgSender(),
            address(this),
            GUMBALL_MACHINE_PRICE
        );
        
        gumballer.gumballerBlocknum = block.number;
        gumballer.gumballerBool = true;
    }
    
    /**
     @notice Cranks lever on the Gumball Machine
     */
    function crankTheLever()
        public
        override
    {
        Gumballers storage gumballer = gumballers[_msgSender()];
        
        // HARD CHECK: Require current Gumball purchase in queue
        require(
              gumballer.gumballerBool == true,
              "No active Gumball found"
        );
        
        // HARD CHECK: Require block.number to be greater than when the token was inserted
        require(
              block.number > (gumballer.gumballerBlocknum + BLOCK_BUFFER),
              "Still processing the previous action, wait a little longer"
        );

        // HARD CHECK: Require block.number to be less than MAX_BLOCKS blocks from when the token was inserted
        require(
              block.number <= (gumballer.gumballerBlocknum + MAX_BLOCKS),
              "Gumball token expired, press the return token button to try again"
        );
        
        gumballer.gumballerBlocknum = (block.number + BLOCK_BUFFER);
        gumballer.honorBool = true;
    }

    /**
     @notice Implements commit/reveal logic to randomly select your Gumball
     */
    function revealYourGumball()
        public
        override
    {
        Gumballers storage gumballer = gumballers[_msgSender()];
        
        // HARD CHECK: Require current Gumball purchase in queue
        require(
              gumballer.gumballerBool == true &&
              gumballer.honorBool == true,
              "No active Gumball found"
        );
        
        // HARD CHECK: Require block.number to be greater than when the lever was cranked
        require(
              block.number > (gumballer.gumballerBlocknum + BLOCK_BUFFER),
              "Still processing the previous action, wait a little longer"
        );

        // HARD CHECK: Require block.number to be less than MAX_BLOCKS blocks from when the lever was cranked
        require(
              block.number <= (gumballer.gumballerBlocknum + MAX_BLOCKS),
              "Gumball token expired, press the return token button to try again"
        );
        
        // Get the blockhash of the locked in gumballer.gumballerBlocknum from the crankTheLever() function
        bytes32 _gumBlockhash = blockhash(gumballer.gumballerBlocknum);
        
        // Packs the blockhash and keccacks it, then takes the remainder (totalGumballs) and that's the random number
        uint256 _gumRand = uint256(keccak256(abi.encodePacked(_gumBlockhash))) % totalGumballs - 1;
        
        // Set the Gumball purchase info back to default
        gumballer.gumballerBlocknum = 0;
        gumballer.gumballerBool = false;
        gumballer.honorBool = false;

        // Get the NFT address and ID for the Gumball won
        address _nftAddress = gumballs[_gumRand].nftAddress;
        uint256 _nftId = gumballs[_gumRand].nftId;

        // Swap the data of the last Gumball added to the machine with the Gumball that was won
        gumballs[_gumRand].nftAddress = gumballs[totalGumballs-1].nftAddress;
        gumballs[_gumRand].nftId = gumballs[totalGumballs-1].nftId;
        gumballs[_gumRand].owner = gumballs[totalGumballs-1].owner;

        lastGumball = _gumRand;

        // Deletes the last Gumball in line (essentially the Gumball that was won, in the form of the last-in-lines' data)
        gumballs.pop();
        totalGumballs--;

        // Deactivate the machine if the totalGumballs drope below the MACHINE_DEACTIVATE_REQUIREMENT (lower bound for the machine to ensure there's enough to go around)
        if (totalGumballs <= MACHINE_DEACTIVATE_REQUIREMENT) {
            isMachineInitialized = false;
        }
        
        // Transfers the randomly selected Gumball to the buyer
        IERC721(_nftAddress).safeTransferFrom(
            IERC721(_nftAddress).ownerOf(_nftId),
            _msgSender(),
            _nftId
        );

       // emit GumballClaimed(_nftAddress, _nftId);
    }

    // INTERNAL FUNCTIONS //

    /**
     @notice Internal function to complete the addGumBall process
     @param _nftAddress ERC 721 Address
     @param _nftId NFT ID
     */
    function _addGumball(address _nftAddress, uint256 _nftId) 
        internal 
    {
        // Transfers NFT ownership to the GumBall machine
        IERC721(_nftAddress).safeTransferFrom(
            IERC721(_nftAddress).ownerOf(_nftId),
            address(this),
            _nftId
        );

        // Catalogues the NFT Address/ID and logs the owner
        gumballs.push();
        gumballs[gumballs.length-1].nftAddress = _nftAddress;
        gumballs[gumballs.length-1].nftId = _nftId;
        gumballs[gumballs.length-1].owner = _msgSender();

        totalGumballs++;
        if (totalGumballs >= MACHINE_ACTIVATE_REQUIREMENT) {
            isMachineInitialized = true;
        }

        emit GumballAdded(_msgSender(), _nftAddress, _nftId);
    }
}
