// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import 'owned.sol';
import 'trc1155.sol';
import 'itrc20.sol';

contract CURNFT is TRC1155, Owned {
  ITRC20 cur_contract;

  uint256 next_tokenID = 0;

  uint256 vesting_length; // Length of vesting when adding more CUR through backing

  mapping (uint256 => uint256) backed;
  mapping (uint256 => bool) allow_more_fractions;
  mapping (uint256 => uint256) outstanding_fractions;
  mapping (uint256 => uint256) vesting_date;
  mapping (uint256 => uint256) total_fractions;

  uint256 totalBacked;

  constructor(address addr) TRC1155('url/{id}.json') {
    cur_contract = ITRC20(addr);
    vesting_length = 100 days;
  }

  function setVestingLength(uint256 length) public isOwner {
    vesting_length = length;
  }

  function _injectCUR(uint256 tokenid, uint256 amt) internal {
    require(cur_contract.balanceOf(msg.sender) >= amt, "Insufficient Funds");
    require(cur_contract.allowance(msg.sender, address(this)) >= amt, "Insufficient Approval");
    cur_contract.transferFrom(msg.sender, address(this), amt);

    if (backed[tokenid] == 0) {
      vesting_date[tokenid] = block.timestamp + vesting_length;
    } else {
      uint256 added_time = (vesting_length * amt) / backed[tokenid];
      if (vesting_date[tokenid] == 0 || vesting_date[tokenid] <= block.timestamp)
        vesting_date[tokenid] = block.timestamp + added_time;
      else
        vesting_date[tokenid] += added_time;
    }

    backed[tokenid] += amt;
    totalBacked += amt;
  }

  function createNFT(uint256 initial_backing, uint256 initial_fractions, bool allow_fractions) public returns (uint256 id) {
    require(address(cur_contract) != address(0));

    allow_more_fractions[next_tokenID] = allow_fractions;

    _injectCUR(next_tokenID, initial_backing);

    _mint(msg.sender, next_tokenID, initial_fractions, "");
    total_fractions[next_tokenID] = initial_fractions;

    next_tokenID++;
    return next_tokenID - 1;
  }

  function burnValue(uint256 tokenid, uint256 fractions) public view returns (uint256 amt) {
    require(address(cur_contract) != address(0));
    require(tokenid < next_tokenID, "NFT does not exist!");
    require(fractions <= outstanding_fractions[tokenId], "NFT does not have sufficient fractions.");

    uint total_bal = cur_contract.balanceOf(address(this));

    uint256 will_receive = (total_bal * backed[tokenId] * fractions) / (totalBacked * outstanding_fractions[tokenId]);

    // Reduce burn value based on how close it is to the vesting date
    if (vesting_date[tokenid] < block.timestamp)
      will_receive = (will_receive * (vesting_length + block.timestamp - vesting_date[tokenid])) / vesting_length;

    return will_receive;
  }

  function canMintFractions(uint256 tokenid) public view returns (bool can_mint) {
    return allow_more_fractions[tokenid];
  }

  function mintFractions(uint256 tokenid, uint256 pay_cur) public returns (uint256 fractions_minted) {
    require(allow_more_fractions[tokenid], "Not allowed to mint additional fractions");
    require(pay_cur > 0, "You must provide CUR");


    uint256 will_receive = (total_fractions[tokenid] * pay_cur) / burnValue(tokenid, total_fractions[tokenid]);
    _mint(msg.sender, tokenid, will_receive, "");

    _injectCUR(tokenid, pay_cur);

    return will_receive;
  }

  // Maybe I shouldn't allow fraction burn and just have a fraction rent system
  function burnFractions(uint256 tokenid, uint256 fractions) public returns (uint256 amt) {
    require(address(cur_contract) != address(0));
    require(tokenid < next_tokenID, "NFT does not exist!");
    require(balanceOf(msg.sender, tokenid) >= fractions, "Insufficient fractions to burn!");

    uint256 b_value = burnValue(tokenid, fractions);

    _burn(msg.sender, tokenid, fractions);
    total_fractions[tokenid] -= fractions;

    // Adjust backing to take account the amount burned: Will this ever throw an exception for going below 0?
    backed[tokenid] -= b_value / cur_contract.balanceOf(address(this));

    cur_contract.transfer(msg.sender, b_value);
  }
}
