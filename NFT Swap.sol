// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//This contract is used for atomic swaps between two NFTs.
contract NFTSwap {
    struct Swap {
        address nft1Contract; //The contract address of the first NFT
        uint256 tokenId1;     //The tokenId of the first NFT
        address nft2Contract; //The contract address of the second NFT
        uint256 tokenId2;     //The tokenId of the second NFT
        address initiator;    //The address of the transaction initiator
        address participant;  //The address of the transaction participant
        bool completed;       //The sign of whether a transaction is completed
    }

    mapping(bytes32 => Swap) private swaps; //Store the mapping of all swaps, with the key being swapId
    
    //Event: Triggered when a new exchange is created
    event SwapCreated(
        bytes32 indexed swapId,     //Let swapId be the index, and in the log, it is for topics.
        address indexed initiator,  //Let initiator be the index, and in the log, it is for topics.
        address nft1Contract,
        uint256 tokenId1,
        address nft2Contract,
        uint256 tokenId2
    );

    //Event: Triggered when the exchange is completed
    event SwapExecuted(bytes32 indexed swapId);
    
    /// @notice Create a new NFT exchange
    /// @dev Ensure that the transaction has not been created yet.
    /// @param nft1Contract The contract address of the first NFT
    /// @param tokenId1 The tokenId of the first NFT
    /// @param nft2Contract The second NFT contract address
    /// @param tokenId2 The tokenId of the second NFT
    function CreateSwap(address nft1Contract, uint256 tokenId1, address nft2Contract, uint256 tokenId2) external {
        //Generate a unique ID for the transaction, based on the hash of the initiator's address and NFT information
        bytes32 swapId = keccak256(abi.encodePacked(msg.sender, nft1Contract, tokenId1, nft2Contract, tokenId2));
        //The requirement for exchange does not exist; avoid repeated creation.
        require(swaps[swapId].initiator == address(0), "Swap already exists");
        //Store the details of the new exchange in the mapping.
        swaps[swapId] = Swap({
            nft1Contract: nft1Contract,
            tokenId1: tokenId1,
            nft2Contract: nft2Contract,
            tokenId2: tokenId2,
            initiator: msg.sender,
            participant: address(0),
            completed: false
        });
        //Trigger the swap creation event
        emit SwapCreated(swapId, msg.sender, nft1Contract, tokenId1, nft2Contract, tokenId2);
    }

    /// @notice Execute NFT exchange
    /// @dev Participants call this function to complete NFT swaps.
    /// @param swapId Unique identifier for the exchange
    function ExecuteSwap(bytes32 swapId) external {
        Swap storage swap = swaps[swapId];  //Obtain the information when creating the exchange
        require(!swap.completed, "Swap already completed"); //Check if the exchange is incomplete to prevent repeated execution
        require(swap.participant == address(0), "Swap already has a participant");//Ensure that the participants have not yet executed this exchange
        require(msg.sender != swap.initiator, "Initiator cannot execute their own swap");//The initiator is prohibited from executing the exchange themselves.
        swap.participant = msg.sender;  //Record the address of the participant
        //Atomic Transfer NFT
        IERC721(swap.nft1Contract).safeTransferFrom(swap.initiator, msg.sender, swap.tokenId1); //Transfer the initiator's NFT to the participant
        IERC721(swap.nft2Contract).safeTransferFrom(msg.sender, swap.initiator, swap.tokenId2); //Transfer the participants' NFTs to the initiator
        swap.completed = true;  // Tag exchange completed
        emit SwapExecuted(swapId);  // Trigger the exchange completion event
    }

    /// @notice Cancel NFT exchange
    /// @dev Only the initiator can cancel
    /// @param swapId Unique identifier for the exchange
    function CancelSwap(bytes32 swapId) external {
        Swap storage swap = swaps[swapId];  //Obtain the information when canceling the exchange
        require(msg.sender == swap.initiator, "Only initiator can cancel"); // Confirm that the canceller is the initiator
        require(!swap.completed, "Swap already completed"); // Confirm that the exchange has not been completed yet
        delete swaps[swapId];   // Delete this exchange record
    }
}