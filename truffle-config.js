var HDWalletProvider = require("truffle-hdwallet-provider");
var mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat";

module.exports = {
  networks: {
    development: {
      //Commented below lines and replace it with host port prop to avoide correct nonce error
      //provider: function() {
      //  return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
      //},
      host: "127.0.0.1",     // Localhost
      port: 7545,            // Standard Ganache UI port
      network_id: '*',
    }
  },
  compilers: {
    solc: {
      version: "^0.4.24"
    }
  }
};