var AddressSetLib = artifacts.require("AddressSet");
var ValidatorListManager = artifacts.require("ValidatorListManager");
var ONLYONET = artifacts.require("ONLYONET");

module.exports = function(deployer) {
  deployer.deploy(AddressSetLib);
  deployer.link(AddressSetLib, ValidatorListManager);
  deployer.deploy(ValidatorListManager);
  deployer.link(AddressSetLib, ONLYONET);
  deployer.deploy(ONLYONET);    
};