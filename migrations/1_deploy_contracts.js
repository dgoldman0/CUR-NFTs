// var contract = artifacts.require("CURNFT");
// //var MetaCoin = artifacts.require("./MetaCoin.sol");

// module.exports = function(deployer) {
//   deployer.deploy(contract, "TMEn6roja4aYhVKkzFFF4aRnK5cEMe4Stp");

//   //nft contract address:  TM4NHo9QY3hDz1XYUYXo8K3JWgiXc7hNgY  /// new : TS5YB9GgduU4i4WB5q5FR5KiTfoyzXPRdS
//   console.log("deployed");
//   // deployer.link(ConvertLib, MetaCoin);
//   // deployer.deploy(MetaCoin);
// };
var contract = artifacts.require("TRC1155NftToken");

module.exports = function(deployer) {
  deployer.deploy(contract);
  console.log("deployed");
};

// FINAL Contracts:

// ERC721 Contract:  TVDSEq59ZvZ3dWgTJd3RsNuG6jPBNT4d9M
// link : https://shasta.tronscan.org/#/contract/TVDSEq59ZvZ3dWgTJd3RsNuG6jPBNT4d9M/code

// ERC20 Contract: TMEn6roja4aYhVKkzFFF4aRnK5cEMe4Stp
// link : https://shasta.tronscan.org/#/contract/TMEn6roja4aYhVKkzFFF4aRnK5cEMe4Stp/code

// ERC1155 Contract: TPobc1GeG8L3QwTJn8ce6Eq8nKVFnzkbUK
// link : https://shasta.tronscan.org/#/contract/TPobc1GeG8L3QwTJn8ce6Eq8nKVFnzkbUK/code
