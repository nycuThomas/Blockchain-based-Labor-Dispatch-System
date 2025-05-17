const Migrations = artifacts.require("IdentityManager");

module.exports = function(deployer) {
  deployer.deploy(Migrations);
};
