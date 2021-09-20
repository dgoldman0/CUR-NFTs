// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";
import "@openzeppelin/contracts/drafts/Counters.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract CURNFT is ERC721Full {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address curContract;

    uint private totalBacking; // Total amount put into backing NFTs

    // Should this be wrapped in a struct?
    mapping (uint => uint) private backing;
    mapping (uint => uint) private createdAt;
    mapping (uint => uint) private lockedUntil;
    mapping (uint => mapping (address => bool)) private backingAllowed;

    event NFTBacked(address indexed _backer, uint indexed _tokenId, uint _amt);
    event Liquidate(address indexed _burner, uint indexed _tokenId, uint _amt);

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
        require(cur > 0, "Some CUR must be used to back NFT.");
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

        return newItemId;
    }

    /**
     * @dev Adds more CUR to back the NFT
     * @param tokenId uint256 id of the ERC721 token to be backed.
     * @param amt uint256 amt of CUR to give.
     */
    function backNFT(uint tokenId, uint amt) public returns (uint) {
      require(ownerOf(tokenId) != address(0), "This token either does not yet exist or has been burned.");
      require(ownerOf(tokenId) == msg.sender || backingAllowed[tokenId][msg.sender], "Only the current NFT owner or authorized addresses can increase backing.");
      require(amt > 0, "Why are you backing with zero?!");

      uint old_backing = backing[tokenId];
      uint new_backing = old_backing + amt;

      require(curContract.balanceOf(msg.sender) > amt);

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

      emit NFTBacked(msg.sender, tokenId, amt);
    }

    // Similar to backNFT, but doesn't increase lockout time. Limited access for obvious reasons. Used by Project Curate to give out bonuses, awards, etc.
    function systemBackNFT() {

    }

    function authorizeBacker() {

    }

    function removeBacker() {

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
        emit Liquidate(msg.sender, tokenId, will_receive);
    }
}
