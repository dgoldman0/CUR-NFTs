// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "ERC721Full.sol";
import "Counters.sol";
import "SafeMath.sol";

import "SafeERC20.sol";
import "Strings.sol";
import "Address.sol";

contract Owned {
  address public owner;
  address public oldOwner;
  uint public tokenId = 1002567;
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
    lastChangedOwnerAt = now;
    oldOwner = owner;
    owner = newOwner;
  }
  // Allow a revert to old owner ONLY IF it has been less than a day
  function revertOwner() public isOldOwner {
    require(oldOwner != owner);
    require((now - lastChangedOwnerAt) * 1 seconds < 86400);
    owner = oldOwner;
  }
}


// Considering changing to ERC1155 standard with an ERC-20 fungible token associated with each NFT to create a fractional NFT system.
// Then we could have the burn/redeem feature generate an "available balance" and use ERC-20 tokens to redeem. Easy for burn, but if I include the redeem feature
// then it becomes much harder to figure out how much each ERC-20 token should yield.
// I would also need to figure out how many tokens are given for each NFT, who has control over it, etc. Most likely it'll have an "ownerMint" feature.

// Another idea along these lines is that tokens are generated when CUR is added. I don't like this approach quite as much, but maybe it's an option.
// I suppose it could always be set up to give the NFT creator the option of creating one or the other.
// One thing is if I do it this way, the owner should not be able to mint more tokens right before they burn, otherwise they could do a rug pull.
contract CURNFT is ERC721Full, Owned {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address curContract;

    uint minimum_mint = 0; // Not fully implemented but will be used to adjust the minimum amount needed to mint an NFT

    uint private totalBacking; // Total amount put into backing NFTs

    mapping (address => bool) private superAllowed; // If true for address then that address can back the NFT without causing an increased lockout

    // Should this be wrapped in a struct?
    mapping (uint => uint) private backing;
    mapping (uint => uint) private createdAt;
    mapping (uint => uint) private lockedUntil;
    mapping (uint => address) nft_issuer; // The address of the person who called the mint function
    mapping (uint => mapping (address => bool)) private backingAllowed;
    // Might want to add MIME type into the NFT info

    event NFTBacker(address indexed _backer, uint indexed _tokenId, uint _amt);
    event Liquidate(address indexed _burner, uint indexed _tokenId, uint _amt);
    event Burn(address indexed _burner, uint indexed _tokenId, uint _amt);

    constructor(address addr) ERC721Full("CURNFT", "CUR") public {
      curContract = addr;
    }

    function getCreatedAt(tokenId) public view returns (uint) {
      return createdAt[tokenId];
    }

    function getLockedUntil(tokenId) public view returns (uint) {
      return lockedUntil[tokenId];
    }

    function getLockoutPeriod(tokenId) public view returns (uint) {
      return lockedUntil[tokenId] - createdAt[tokenId];
    }

    function timeUntilUnlocked(tokenId) public view returns (uint) {
      if (now >= lockedUntil[tokenId]) return 0;
      return lockedUntil[tokenId] - now;
    }

    function getBacking(uint tokenId) public view returns (uint) {
      return backing[tokenId];
    }

    function isBackingAllowed(uint tokenId, address addr) public view returns (bool) {
      return backingAllowed[tokenId][addr];
    }

    function allowBacker(uint tokenId, address addr) public returns (bool) {
      require(ownerOf(tokenId) == msg.sender, "Only the NFT owner can alter backers.");
      backingAllowed[tokenId][addr] = true;
      return true;
    }

    function disallowBacker(uint tokenId, address addr) public returns (bool) {
      require(ownerOf(tokenId) == msg.sender, "Only the NFT owner can alter backers.");
      backingAllowed[tokenId][addr] = false;
      return true;
    }

    function createNFT(uint cur, uint lockout_time, string memory tokenURI) public returns (uint256) {
        require(curContract != address(0), "Token address has not yet been set!");
        require(cur >= minimum_mint || msg.sender == owner, "Some CUR must be used to back NFT.");
        require(lockout_time > 30 days , "Minimum lockout is 30 days.");

        uint balance = curContract.balanceOf(msg.sender);
        require(balance >= cur, "Insufficient CUR to back NFT.");

        uint allowance = curContract.allowance(msg.sender, address(this));
        require(allowance >= cur, "Not enough tokens approved prior to minting");
    		curContract.transferFrom(msg.sender, address(this), cur);

        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);

        backing[newItemId] = cur;

        uint created_at = now;

        createdAt[newItemId] = created_at;
        lockedUntil[newItemId] = created_at + lockout_time;
        nft_issuer[newItemId] = msg.sender;

        return newItemId;
    }

    /**
     * @dev Adds more CUR to back the NFT
     * @param tokenId uint256 id of the ERC721 token to be backed.
     * @param amt uint256 amt of CUR to give.
     *
     * This backing system is nice and simple. However, it could be really nice to have a rolling system where each individual backing slowly reaches maturity.
     * It would require a heavy rewrite as instead of a single backing, I would probably need a linked list of <backing_amount, date_backed>
     */
    function backNFT(uint tokenId, uint amt) public returns (uint) {
      require(ownerOf(tokenId) != address(0), "This token either does not yet exist or has been burned.");
      require(ownerOf(tokenId) == msg.sender || backingAllowed[tokenId][msg.sender] || superAllowed[msg.sender], "Only the current NFT owner or authorized addresses can increase backing.");
      require(amt > 0, "Why are you backing with zero?!");

      uint old_backing = backing[tokenId];
      uint new_backing = old_backing + amt;

      uint balance = curContract.balanceOf(msg.sender);
      require(balance >= amt, "Insufficient CUR to back NFT.");

      uint allowance = curContract.allowance(msg.sender, address(this));
      require(allowance >= amt, "Not enough tokens approved prior to minting");
      curContract.transferFrom(msg.sender, address(this), amt);

      // Update lockout time
      uint lo_len = lockedUntil[tokenId] - createdAt[tokenId];
      uint add_time = lo_len * (new_backing/old_backing - 1);
      if (add_time > 1000 days) add_time = 1000 days; // Prevent any amount from adding more than 1,000 additional days to lockout period.
      lockedUntil[tokenId] = createdAt[tokenId] + lo_len + add_time;

      backing[tokenId] = new_backing;
      totalBacking += amt;

      emit NFTBacker(msg.sender, tokenId, amt);
    }

    // Similar to backNFT, but doesn't increase lockout time. Limited access for obvious reasons. Used by Project Curate to give out bonuses, awards, etc.
    function systemBackNFT(uint256 tokenId, uint256 amt) public {
      require(isSuperAllowed[msg.sender], "Not authorized, please use backNFT operation instead.");

      uint balance = curContract.balanceOf(msg.sender);
      require(balance >= amt, "Insufficient CUR to back NFT.");

      uint allowance = curContract.allowance(msg.sender, address(this));
      require(allowance >= amt, "Not enough tokens approved prior to minting");
      curContract.transferFrom(msg.sender, address(this), amt);

      backing[tokenId] = backing[tokenId] + amt;
      totalBacking += amt;
    }

    function allowSuper(address addr) public isOwner {
      superAllowed[addr] = true;
    }

    function disallowSuper(address addr) public isOwner {
      superAllowed[addr] = false;
    }

    // Returns the amount of CUR that the user would receive if they burned the NFT.
    // When single backing is rewritten to allow for a linked list of multiple backings, burnValue will traverse the list to calculate the total burn value
    function burnValue(uint256 tokenId) public view returns (uint256 amt) {
      uint backed = backing[tokenId];
      uint total = totalBacking;
      backing[tokenId] = 0;

      address t_owner = ownerOf(tokenId);

      // Need to replace this section with a _willReceive function which will calculate how much a user will receive on burn.
      uint bal = curContract.balanceOf(address(this));
      uint lo_len = lockedUntil[tokenId] - createdAt[tokenId];

      // Calculate multiplier based on how much time the NFT was locked
      uint t_mult = lo_len / 500 days;
      if (t_mult < 0.2) t_mult = 0.2;
      if (t_mult > 5) t_mult = 5;
      uint mult = bal / total;

      uint will_receive = backed * mult * t_mult;
      if (will_receive < backed) will_receive = backed; // No matter the multiplier, make sure the person gets at least what is staked.
      return will_recieve;
    }

    /**
     * @dev Burns a specific ERC721 token.
     * @param tokenId uint256 id of the ERC721 token to be burned.
     */
    function burn(uint256 tokenId) public {
        require(_isApprovedOrOwner(msg.sender, tokenId));
        require(lockedUntil <= now, "Lockout period has not ended.");

        uint backed = backing[tokenId];
        uint total = totalBacking;
        backing[tokenId] = 0;

        address t_owner = ownerOf(tokenId);
        _burn(tokenId);

        // Need to replace this section with a _willReceive function which will calculate how much a user will receive on burn.
        uint bal = curContract.balanceOf(address(this));
        uint lo_len = lockedUntil[tokenId] - createdAt[tokenId];

        // Calculate multiplier based on how much time the NFT was locked
        uint t_mult = lo_len / 500 days;
        if (t_mult < 0.2) t_mult = 0.2;
        if (t_mult > 5) t_mult = 5;
        uint mult = bal / total;

        uint will_receive = backed * mult * t_mult;
        if (will_receive < backed) will_receive = backed; // No matter the multiplier, make sure the person gets at least what is staked.

        // It shouldn't ever happen but if the contract doesn't have enough CUR, the system will revert.
        require(bal >= will_receive, "Insufficient CUR in the contract!");

        totalBacking -= backed;

        curContract.transfer(t_owner, will_receive);
        emit Burn(msg.sender, tokenId, will_receive);
    }

    /* @dev Liquidates an NFT
    * Like burn, but allows the original NFT to be preserved. Because the NFT is being preserved, there's a 20% penalty.
    * @param tokenId uint256 id of the ERC721 token to be burned.
    */
    function redeem(uint256 tokenId) {

    }

}
