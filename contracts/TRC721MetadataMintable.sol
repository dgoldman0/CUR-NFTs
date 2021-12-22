// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

// import "./@openzeppelin/contracts/token/TRC721/TRC721.sol";
// import "./@openzeppelin/contracts/token/TRC721/extensions/TRC721Metadata.sol";
// import "./MinterRole.sol";

// /**
//  * @title TRC721MetadataMintable
//  * @dev TRC721 minting logic with metadata.
//  */
// contract TRC721MetadataMintable is TRC721, TRC721Metadata, MinterRole {
//     /**
//      * @dev Function to mint tokens.
//      * @param to The address that will receive the minted tokens.
//      * @param tokenId The token id to mint.
//      * @param tokenURI The token URI of the minted token.
//      * @return A boolean that indicates if the operation was successful.
//      */
//     function mintWithTokenURI(address to, uint256 tokenId, string memory tokenURI) public onlyMinter returns (bool) {
//         _mint(to, tokenId);
//         _setTokenURI(tokenId, tokenURI);
//         return true;
//     }
// }