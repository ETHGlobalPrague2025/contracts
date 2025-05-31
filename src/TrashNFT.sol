// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/**
 * @title TrashNFT
 * @dev NFT for the gamified recycling system, awarded for completing quests
 */
contract TrashNFT is ERC721URIStorage, Ownable {
    uint256 private _nextTokenId;

    // Mapping from token ID to quest ID
    mapping(uint256 => uint256) public tokenQuests;

    constructor() ERC721("TrashNFT", "TNFT") Ownable(msg.sender) {}

    /**
     * @dev Mints a new NFT to the specified address
     * @param to The address to mint the NFT to
     * @param questId The ID of the quest that was completed
     * @param tokenURI The URI for the token metadata
     * @return The ID of the newly minted token
     */
    function mintNFT(address to, uint256 questId, string memory tokenURI) external onlyOwner returns (uint256) {
        uint256 tokenId = _nextTokenId++;
        
        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);
        tokenQuests[tokenId] = questId;
        
        return tokenId;
    }

    /**
     * @dev Returns the quest ID associated with a token
     * @param tokenId The ID of the token
     * @return The ID of the quest
     */
    function getQuestId(uint256 tokenId) external view returns (uint256) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        return tokenQuests[tokenId];
    }
}
