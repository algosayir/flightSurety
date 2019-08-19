import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';
require('babel-polyfill')
const bodyParser = require('body-parser')

let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);

//Oracle Initialization
//Upon startup, 20+ oracles are registered and their assigned indexes are persisted in memory
(async () => {
  console.log("HI");
  try{
    let accounts = await web3.eth.getAccounts();
    console.log(accounts.length);
    let fee = web3.utils.toWei('1', 'ether');//await flightSuretyApp.REGISTRATION_FEE.call();
    console.log(fee);

    for(let i = 1; i < 22; i++){
      //console.log(accounts[i]);
      await flightSuretyApp.methods.registerOracle().send({from: accounts[i], value: fee, gas:6721975})
    }
    console.log("Oracles are registered successfully...")
  } catch(errpr){
    console.log(errpr);
  }
})();

const getRandomStatusCode = () => {
  let status = [10, 20, 30, 40, 50];
  return status[Math.floor(Math.random() * status.length)];
}

flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)
}).on('data', async event => {
  let args = event.returnValues;

  console.log(`Index: ${args.index}, Airline: ${args.airline}, Flight: ${args.flight}, Timestamp: ${args.timestamp}`);

  let accounts = await web3.eth.getAccounts();
  try {
    for (let i = 1; i < 22; i++) {
        let s = getRandomStatusCode();
        //console.log("account:"+accounts[i]+" status:"+s);
        const indexes = await flightSuretyApp.methods.getMyIndexes().call({ from: accounts[i] });
        for(let m = 0; m < indexes.length; m++){
          try{
            await flightSuretyApp.methods.submitOracleResponse(indexes[m], args.airline, args.flight, args.timestamp, s).send({
              from: accounts[i]
            });
            console.log("Oracle Response Submitted:\n");
            console.log(`Index: ${indexes[m]}, Airline: ${args.airline}, Flight: ${args.flight}, Timestamp: ${args.timestamp}, status: ${s}`);
          } catch(ee){
            //Ignore uninvited oracles since they are not welcome ;)
            //console.log("===========================");
            //console.log(ee);
          }
        }
    };
  } catch (err) {
    console.log(err);
  }
});


const app = express();
app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
})

export default app;


