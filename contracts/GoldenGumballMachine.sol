// SPDX-License-Identifier: MIT
// Welcome to the Golden Gumball Machine

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IGoldenGumballMachine.sol";

contract GoldenGumballMachine is 
    IGoldenGumballMachine, 
    ERC721, 
    ERC721Holder, 
    Ownable, 
    ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor (address _owner, address _payToken) ERC721("Golden Gumball Tokens", "GUM") {
        GUM = IERC721(address(this));
        payToken = IERC20(_payToken);
        transferOwnership(_owner);
    }

    // STRUCTS, MAPPINGS, AND ARRAYS //
    
    // Parameters of Gumballers (shot callers, 20" blades, on the Impala)
    struct Gumballers {
        uint256 gumballerBlocknum;
        uint256 myGoldenToken;
        bool gumballerBool;
        bool myHonorBool;
    }
    
    // Parameters of Gumballs
    struct Gumballs {
        address nftAddress;
        uint256 nftId;
        address owner;
    }

    mapping(address => Gumballers) public gumballers;
    Gumballs[] public gumballs;

    // Parameters of Whitelisted Tokens
    struct Whitelist {
        bool status;
    }

    mapping(address => Whitelist) public whitelist;

    // Parameters of Tickets
    struct Tickets {
        address owner;
    }

    Tickets[] public tickets;

    // CONSTANTS AND GLOBAL VARIABLES //

    // ERC20 interfaces
    IERC721 public GUM;
    IERC20 public payToken;

    // Bool to ensure the machine has sufficient Gumballs inserted before allowing tokens to be inserted
    bool public isMachineInitialized;

    // Golden Gumball Machine global variables
    uint256 public totalGumballs;
    uint256 public lastGumball;

    uint256 public drawingEndTimestamp;
    uint256 public lastDrawingTimestamp;

    uint256 private goldenBlock;
    bool private goldenBool;
    bool private honorBool;

    uint256 public totalTickets;
    uint256 public lastWinningTicket;

    uint256 public totalGoldenTokens;
    
    uint256 public blockNum;

    // Golden Gumball Machine admin-set variables
    uint256 public ENTRY_PRICE;

    uint256 public MACHINE_ACTIVATE_REQUIREMENT;
    uint256 public MACHINE_DEACTIVATE_REQUIREMENT;

    bool public drawingRepeatStatus;
    bool public drawingActive;
    uint256 public drawingDuration;

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
    
    function setPayToken(address _payToken) public onlyOwner {
        payToken = IERC20(_payToken);
    }

    function setEntryPrice(uint256 _price) public onlyOwner {
        ENTRY_PRICE = _price;
    }

    function setActiveRequirements(uint256 _deactivate, uint256 _activate) public onlyOwner {
        MACHINE_DEACTIVATE_REQUIREMENT = _deactivate;
        MACHINE_ACTIVATE_REQUIREMENT = _activate;
    }

    function setWhitelistStatus(address _nftAddress, bool _status) public onlyOwner {
        Whitelist storage _whitelisted = whitelist[_nftAddress];
        _whitelisted.status = _status;
    }

    function setDrawingRepeatStatus(bool _status) public onlyOwner {
        drawingRepeatStatus = _status;
    }

    function setBlockNum(uint256 _blockNum) public {
        blockNum = _blockNum;
    }

    function initializeDrawing(uint256 _duration, bool _repeatDrawing) public gumballMachineActive onlyOwner {
        require(
            _duration >= 0,
            "Duration must be longer"
        );

        require(
            block.number > drawingEndTimestamp,
            "Cannot initialize in the middle of a drawing"
        );

        drawingDuration = _duration;
        drawingRepeatStatus = _repeatDrawing;
        drawingActive = true;
        drawingEndTimestamp = (block.timestamp + _duration);
    }

    // EXTERNAL FUNCTIONS //

    /**
     @notice External function to enter into the Golden Gumball drawing
     */
    function enterDrawing() 
        external 
        override 
        gumballMachineActive
        nonReentrant 
    {
        // HARD CHECK: Requires the drawing be active before proceeding
        require(
            block.timestamp < drawingEndTimestamp &&
            block.timestamp > lastDrawingTimestamp &&
            drawingActive == true,
            "Drawing isn't currently active"
        );

        // HARD CHECK: Requires the _msgSender() to have enough ERC20 tokens to transfer
        require(
            payToken.transferFrom(_msgSender(), address(this), ENTRY_PRICE),
            "Insufficient balance or not approved"
        );

        _enterDrawing();
    }

    /**
     @notice Fixes stale drawing (drawing that was started and never finished before the MAX_BLOCKS buffer)
     */
    function fixStaleDrawing()
        public
        override
    {
        // HARD CHECK: Require the drawing to be started before fixing
        require(
              goldenBool == true,
              "No drawing found"
        );

        // HARD CHECK: Require block.number to be greater than MAX_BLOCKS blocks from when the drawing began
        require(
              block.number > (goldenBlock + MAX_BLOCKS),
              "Drawing isn't stale"
        );
        
        goldenBool = false;
        honorBool = false;
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
              gumballer.myHonorBool == false,
              "No token found"
        );

        // HARD CHECK: Require block.number to be greater than MAX_BLOCKS blocks from when the token was inserted
        require(
              block.number > (gumballer.gumballerBlocknum + MAX_BLOCKS),
              "Token isn't stale"
        );

        // Returns Golden Gumball Token
        GUM.safeTransferFrom(
            address(this),
            _msgSender(),
            gumballer.myGoldenToken
        );
        
        gumballer.gumballerBool = false;
    }

    /**
     @notice Fixes account status in the event that a user inserted a token, cranked the lever, then waited longer than the allowed time, this will not return the token for security reasons
     */
    function fixStatus()
        public
        override
    {
        Gumballers storage gumballer = gumballers[_msgSender()];

        // HARD CHECK: Require a token be inserted before fixing
        require(
              gumballer.gumballerBool == true &&
              gumballer.myHonorBool == true,
              "No token found"
        );

        // HARD CHECK: Require block.number to be greater than MAX_BLOCKS blocks from when the lever was cranked
        require(
              block.number > (gumballer.gumballerBlocknum + MAX_BLOCKS),
              "Token hasn't expired yet"
        );
        
        gumballer.gumballerBool = false;
        gumballer.myHonorBool = false;
    }

    /**
     @notice External function to begin the drawing
     */
    function beginDrawing() 
        external 
        override 
        gumballMachineActive
        nonReentrant 
    {
        // HARD CHECK: Requires the drawing be completed before proceeding
        require(
            block.timestamp > drawingEndTimestamp &&
            drawingActive == true,
            "Drawing isn't currently active or entry period hasn't ended"
        );

        // HARD CHECK: Require no current Gumball purchase in queue
        require(
              goldenBool == false,
              "Drawing has already started"
        );

        goldenBlock = block.number;
        goldenBool = true;
    }

    /**
     @notice Shuffles around all the tickets (fully commits to the drawing, winner must be picked within MAX_BLOCKS or drawing is null)
     */
    function shuffleTickets()
        public
        override
    {
        // HARD CHECK: Require the drawing to be started before shuffling
        require(
              goldenBool == true,
              "Drawing hasn't started"
        );
        
        // HARD CHECK: Require block.number to be greater than when the drawing began
        require(
              block.number > (goldenBlock + BLOCK_BUFFER),
              "Still processing the previous action, wait a little longer"
        );

        // HARD CHECK: Require block.number to be less than MAX_BLOCKS blocks from when the drawing began
        require(
              block.number <= (goldenBlock + MAX_BLOCKS),
              "Stale drawing, fixStaleDrawing and restart the drawing"
        );
        
        goldenBlock = (block.number + BLOCK_BUFFER);
        honorBool = true;
    }

    /**
     @notice Implements commit/reveal logic to randomly select the winner
     */
    function pickTheWinner()
        public
        override
    {
        // HARD CHECK: Require the tickets be shuffled before picking a winner
        require(
              goldenBool == true &&
              honorBool == true,
              "No active drawing found"
        );
        
        // HARD CHECK: Require block.number to be greater than when the drawing began
        require(
              block.number > (goldenBlock + BLOCK_BUFFER),
              "Still processing the previous action, wait a little longer"
        );

        // HARD CHECK: Require block.number to be less than MAX_BLOCKS blocks from when the drawing began
        require(
              block.number <= (goldenBlock + MAX_BLOCKS),
              "Stale drawing, fixStaleDrawing and restart the drawing"
        );
        
        // Get the blockhash of the locked in goldenBlock from the shuffleTickets() function
        bytes32 _goldenBlockhash = blockhash(goldenBlock);
        
        // Packs the blockhash and keccacks it, then takes the remainder (totalTickets) and that's the random number
        uint256 _goldenRand = uint256(keccak256(abi.encodePacked(_goldenBlockhash))) % totalTickets - 1;
        
        // Set the Golden Gumball info back to default
        goldenBlock = 0;
        goldenBool = false;
        honorBool = false;

        // Get the owner of the winning ticket
        address _winner = tickets[_goldenRand].owner;

        // Swap the data of the last ticket purchased with the winning ticket
        tickets[_goldenRand].owner = tickets[totalTickets-1].owner;

        lastWinningTicket = _goldenRand;

        // Deletes the last Ticket in line (essentially the Ticket that was won, in the form of the last-in-lines' data)
        tickets.pop();
        totalTickets--;
        
        // Mints a Golden Gumball Token for the winner
        super._mint(_winner, totalGoldenTokens);

        totalGoldenTokens++;
        
        lastDrawingTimestamp = drawingEndTimestamp;
        // Restarts the drawing if the drawingRepeatStatus is true, else it sets the drawing to inactive
        if (drawingRepeatStatus == true) {
            drawingEndTimestamp = (block.timestamp + drawingDuration);
        } else {
            drawingActive = false;
        }
    }

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

        // HARD CHECK: Requires the NFT address be whitelisted to add to the machine
        Whitelist memory _whitelisted = whitelist[_nftAddress];
        require(
            _whitelisted.status = true, 
            "NFT address isn't current whitelisted"
        );

        // Call internal function _addGumball to complete the addGumBall process
        _addGumball(
            _nftAddress,
            _nftId
        );
    }

    /**
     @notice Inserts Golden Gumball Token into the machine
     */
    function insertGumballToken(uint256 _nftId)
        public
        override
        nonReentrant
        onlyNotContract
        gumballMachineActive
    {
        Gumballers storage gumballer = gumballers[_msgSender()];
        
        // HARD CHECK: Require the sender be the owner of the Golden Gumball Token
        require(
            IERC721(address(this)).ownerOf(_nftId) == _msgSender(),
                "You don't own this Golden Gumball Token"
        );
        
        // HARD CHECK: Require no current Gumball purchase in queue
        require(
              gumballer.gumballerBool == false,
              "Golden Gumball already purchased"
        );

        // HARD CHECK: Requires Gumball contract to be approved
        require(
            IERC721(address(this)).isApprovedForAll(
                _msgSender(),
                address(this)
            ),
            "Golden Gumball hasn't been approved"
        );

        // Inserts Golden Gumball Token into the machine
        GUM.safeTransferFrom(
            _msgSender(),
            address(this),
            _nftId
        );
        
        gumballer.gumballerBlocknum = block.number;
        gumballer.gumballerBool = true;
    }
    
    /**
     @notice Cranks lever on the Golden Gumball Machine
     */
    function crankTheLever()
        public
        override
    {
        Gumballers storage gumballer = gumballers[_msgSender()];
        
        // HARD CHECK: Require current Golden Gumball purchase in queue
        require(
              gumballer.gumballerBool == true,
              "No active Golden Gumball found"
        );
        
        // HARD CHECK: Require block.number to be greater than when the token was inserted
        require(
              block.number >= (gumballer.gumballerBlocknum + BLOCK_BUFFER),
              "Still processing the previous action, wait a little longer"
        );

        // HARD CHECK: Require block.number to be less than MAX_BLOCKS blocks from when the token was inserted
        require(
              block.number <= (gumballer.gumballerBlocknum + MAX_BLOCKS),
              "Gumball token expired, press the return token button to try again"
        );
        
        gumballer.gumballerBlocknum = (block.number + BLOCK_BUFFER);
        gumballer.myHonorBool = true;
    }

    /**
     @notice Implements commit/reveal logic to randomly select your Gumball
     */
    function revealYourGumball()
        public
        override
    {
        Gumballers storage gumballer = gumballers[_msgSender()];
        
        // HARD CHECK: Require current Golden Gumball purchase in queue
        require(
              gumballer.gumballerBool == true &&
              gumballer.myHonorBool == true,
              "No active Gumball found"
        );
        
        // HARD CHECK: Require block.number to be greater than when the lever was cranked
        require(
              block.number >= (gumballer.gumballerBlocknum + BLOCK_BUFFER),
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
        
        // Set the Gumballer purchase info back to default
        gumballer.gumballerBlocknum = 0;
        gumballer.gumballerBool = false;
        gumballer.myHonorBool = false;

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

    /**
     @notice Internal function to enter the Golden Gumball Token drawing
     */
    function _enterDrawing() 
        internal 
    {
        // Catalogues the Ticket owner
        tickets.push();
        tickets[tickets.length-1].owner = _msgSender();
        totalTickets++;
    }
}
