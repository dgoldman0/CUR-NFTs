// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

contract Owned {
  address public owner;
  address public oldOwner;
  uint public tokenId = 1001108; // Make sure to change this back before going live!
//  uint public tokenId = 1002567;
  uint lastChangedOwnerAt;
  constructor() {
    owner = msg.sender;
    oldOwner = owner;
  }
  modifier isOwner() {
    require(msg.sender == owner);
    _;
  }
  modifier isOldOwner() {
    require(msg.sender == oldOwner);
    _;
  }
  modifier sameOwner() {
    address addr = msg.sender;
    // Ensure that the address is a contract
    uint size;
    assembly { size := extcodesize(addr) }
    require(size > 0);

    // Ensure that the contract's parent is
    Owned own = Owned(addr);
    require(own.owner() == owner);
     _;
  }
  // Be careful with this option!
  function changeOwner(address newOwner) public isOwner {
    lastChangedOwnerAt = block.timestamp;
    oldOwner = owner;
    owner = newOwner;
  }
  // Allow a revert to old owner ONLY IF it has been less than a day
  function revertOwner() public isOldOwner {
    require(oldOwner != owner);
    require((block.timestamp - lastChangedOwnerAt) * 1 seconds < 86400);
    owner = oldOwner;
  }
}
