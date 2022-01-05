var Verifier = artifacts.require("Verifier");
var DarkForest = artifacts.require("DarkForest");
var DFPlayer = artifacts.require("DFPlayer");
module.exports = function(deployer) {
  deployer.deploy(Verifier)
    .then(function(){
        return deployer.deploy(DarkForest, Verifier.address)
  })
    .then(function(){
        return deployer.deploy(DFPlayer, DarkForest.address)
  });
};