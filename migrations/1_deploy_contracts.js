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