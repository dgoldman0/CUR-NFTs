// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./@openzeppelin/contracts/token/TRC1155/TRC1155.sol";
import "./@openzeppelin/contracts/access/Ownable.sol";

contract TRC1155Token is TRC1155, Ownable {
    uint256 public tokenCounter;
    uint private newItem;
    constructor() TRC1155(""){
        tokenCounter = 1;
    }

    function createNft(string memory _url, uint256 _amount) public returns(uint256){
        newItem = tokenCounter;
        _mint(msg.sender, newItem, _amount, "");
        _setURI(_url);
        tokenCounter = tokenCounter + 1;
        return newItem;
    }
}