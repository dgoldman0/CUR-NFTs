// Built in Safe Math wrapper makes things a lot easier, so I'll be sticking with 0.8+
pragma solidity ^0.8.0;
import 'owned.sol';

interface ForgableToken {
  /// @return supply Total amount of tokens
  function totalSupply() external view returns (uint256 supply);
  /// @param _owner The address from which the balance will be retrieved
  /// @return balance The user's balance
  function balanceOf(address _owner) external view returns (uint256 balance);
  /// @notice send `_value` token to `_to` from `msg.sender`
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return success Whether the transfer was successful or not
  function transfer(address _to, uint256 _value) external returns (bool success);
  /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
  /// @param _from The address of the sender
  /// @param _to The address of the recipient
  /// @param _value The amount of token to be transferred
  /// @return success Whether the transfer was successful or not
  function transferFrom(address _from, address _to, uint256 _value) external returns (bool success);
  /// @notice `msg.sender` approves `_addr` to spend `_value` tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @param _value The amount of wei to be approved for transfer
  /// @return success Whether the approval was successful or not
  function approve(address _spender, uint256 _value) external returns (bool success);
  /// @param _owner The address of the account owning tokens
  /// @param _spender The address of the account able to transfer the tokens
  /// @return remaining Amount of remaining tokens allowed to spent
  function allowance(address _owner, address _spender) external view returns (uint256 remaining);

  // Forge specific properties that need to be included in the contract
  /// @return success Whether the forging was successful or not
  function forge() external payable returns (bool success);
  function maxForge() external view returns (uint256 amount);
  function baseConversionRate() external view returns (uint256 best_price);
  function timeToForge(address addr) external view returns (uint256 time);
  function forgePrice() external returns (uint256 price);
  function smithCount() external view returns (uint256 count);
  function smithFee() external view returns (uint256 fee);
  function canSmith() external view returns (bool able);
  function canSmith(address addr) external view returns (bool);
  function totalWRLD() external view returns (uint256 wrld);
  function firstMint() external view returns (uint256 date);
  function lastMint() external view returns (uint256 date);
  function paySmithingFee() external payable returns (bool fee);

  event Transfer(address indexed _from, address indexed _to, uint256 _value);
  event Approval(address indexed _owner, address indexed _spender, uint256 _value);
  event Forged(address indexed _to, uint _cost, uint _amt);
  event NewSmith(address indexed _address, uint _fee);
}

// CUR Token
contract CURToken is ForgableToken, Owned {
  address public nftContract;

  constructor() {
    totalSupply = 2000000000000;
    name = "Project Curate Token";
    symbol = "CUR";
    decimals = 6;
    sendTo = payable(msg.sender);
    emit Forged(msg.sender, 0, totalSupply);
    emit Transfer(address(this), msg.sender, totalSupply);
    balances[msg.sender] = totalSupply;
  }

  // Allows the owner to set the address for the NFT contract once.
  function setNFTContract(address addr) public isOwner returns (bool success) {
    require(nftContract == address(0), "Address already set.");
    nftContract = addr;
    return true;
  }

  function transfer(address _to, uint256 _value) public override returns (bool success) {
      if (balances[msg.sender] >= _value && _value > 0) {
          balances[msg.sender] -= _value;
          balances[_to] += _value;
          emit Transfer(msg.sender, _to, _value);
          return true;
      } else { return false; }
  }

  function transferFrom(address _from, address _to, uint256 _value) public override returns (bool success) {
      if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
          balances[_to] += _value;
          balances[_from] -= _value;
          allowed[_from][msg.sender] -= _value;
          emit Transfer(_from, _to, _value);
          return true;
      } else { return false; }
  }

  function balanceOf(address _owner) public view override returns (uint256 balance) {
      return balances[_owner];
  }

  function approve(address _spender, uint256 _value) public override returns (bool success) {
      allowed[msg.sender][_spender] = _value;
      emit Approval(msg.sender, _spender, _value);
      return true;
  }

  function allowance(address _owner, address _spender) public view override returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  mapping (address => uint256) balances;
  mapping (address => mapping (address => uint256)) allowed;
  uint256 public override totalSupply;
  string public name;
  string public symbol;
  uint8 public decimals;

  /* This is where all the special operations will occur */
  // Returns the maximum amount of WRLD that can be sent to mint new tokens
  function maxForge() public view override returns (uint256) {
    if (totalWRLD / 1000 < 100000000000) return 100000000000;
    return totalWRLD / 1000;
  }

  // Returns the number of seconds until the user can mint tokens again
  function timeToForge(address addr) external view override returns (uint256) {
    uint256 dif = (block.timestamp - lastMinted[addr]);
    if (dif > 3600) return 0;
    return 3600 - dif;
  }

  // Mints new tokens based on how many tokens have already been minted
  // Tempted to require a minting fee...
  function forge() external payable override returns (bool success) {
    require(nftContract != address(0), "No NFT contract address set!");
    // Limit minting rate to the greater of 0.1% of the amount of WRLD frozen so far or 100,000 WRLD
    require(msg.tokenid == tokenId, "Wrong Token");
    require(msg.tokenvalue <= 100000000000 || msg.tokenvalue <= totalWRLD / 1000, "Maximum WRLD Exceeded");
    require(msg.sender == owner || paid[msg.sender], "Not a Registered Smith");

    // Only let a person mint once per hour
    uint256 start = block.timestamp;
    require(start - lastMinted[msg.sender] > 3600, "Too Soon to Forge Again");

    // Calculate the amount of token to be minted. Make sure that there's no chance of overflow!
    uint256 amt = msg.tokenvalue / _calculateCost(start);

    // Freeze WRLD
    sendTo.transferToken(msg.tokenvalue, tokenId);

    // Mint tokens
    uint256 boost = amt / 10;
    totalSupply += amt + boost;
    emit Forged(msg.sender, msg.tokenvalue, amt);

    // Send them to the minter
    balances[msg.sender] += amt;
    balances[nftContract] += boost;
    emit Transfer(address(this), address(msg.sender), amt);
    emit Transfer(address(this), address(nftContract), boost);
    lastMinted[msg.sender] = start;
    if (firstMint == 0) firstMint = start;
    lastMint = start;
    totalWRLD += msg.tokenvalue;
    return true;
  }

  // Base Minting
  // While the forge system is open to everyone, and can be used to increase the supply at a cost of WRLD, a supply of tokens will be needed to distribute to our responders.
  // This function will allow a cetain number of tokens to be minted to fund this effort.
  uint256 public lastOwnerMint;
  uint8 public remaining = 24; // Used to decrease the owner mint rate over time, allowing for an initially high rate to fund initial efforts.

  function ownerMint() public isOwner returns (bool success) {
    uint256 start = block.timestamp;
    if (start - lastOwnerMint > 2592000) {
      lastOwnerMint = start;
      uint256 amt = (totalSupply * remaining) / 2400;
      totalSupply += amt;
      emit Forged(owner, 0, amt);
      if (remaining > 1) remaining -= 1;
      balances[owner] += amt;
      emit Transfer(address(this), address(owner), amt);
      return true;
    }
    return false;
  }

  // Get the current conversion rate
  function _calculateCost(uint256 _now) internal returns (uint256) {
    if (firstMint == 0) return baseConversionRate;
    uint256 time1 = (_now - firstMint);
    uint256 time2 = (_now - lastMint);
    uint256 conv = (time1 * 100) / (time2 * time2 * time2 + 1);
    if (conv < 100) conv = 100; // Don't let people forge for free!
    if (conv > 10000) conv = 10000;
    return (baseConversionRate * conv) / 100;
  }
  // Price to mint one ARC token: not sure why it's making me forgo "view" since nothing in _calculateCost does change state  
  function forgePrice() external override returns (uint256) {
    return _calculateCost(block.timestamp);
  }
  // Allow's the change of the address to which frozen tokens go. Can only be done if sendTo is the default or within the first week after it's changed
  function changeSendTo(address payable newAddr) public isOwner {
    require(sendTo == payable(owner) || (block.timestamp - setAt) < 604800); // Add || sendTo == TMPxbVA2Lb6tMBQfffMPSoNtSJLKnhFhwE in case I want to upgrade the faucet at some point
    setAt = block.timestamp;
    sendTo = newAddr;
  }
  function canSmith(address addr) public view override returns (bool) {
    return addr == owner || paid[msg.sender];
  }
  function canSmith() external view override returns (bool) {
    return canSmith(msg.sender);
  }
  function paySmithingFee() external payable override returns (bool success) {
    if (paid[msg.sender] || msg.value != smithFee || msg.sender == owner) return false;
    payable(owner).transfer(msg.value);
    // Every ten smiths increases the smith fee by 100 TRX
    if (smithFee < 1000000000 && (smithCount + 1) % 10 == 0) smithFee += 100000000;
    smithCount++;
    paid[msg.sender] = true;
    emit NewSmith(msg.sender, msg.value);
    return true;
  }

  mapping (address => uint256) public lastMinted;
  mapping (address => bool) public paid;

  uint256 public override smithCount;
  uint256 public override smithFee = 10000000;
  uint256 public override baseConversionRate = 1; // 1 WRLD = 1 CUR
  uint256 public override totalWRLD; // Total amount of world used to mint
  uint256 public override firstMint; // Date of the first minting
  uint256 public override lastMint; // Date of most recent minting
  address payable public sendTo;
  uint256 setAt;
}
