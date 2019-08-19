import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {

        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        console.log(payload);
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }
    
    purchageFlightInsurance(flight, insurace_value, callback) {
        //purchageFlightInsurance(
        //     address airline,
        //     string flight,
        //     uint256 timestamp
        // )
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        //console.log("Here PFI function");
        self.flightSuretyApp.methods
            .purchageFlightInsurance(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner, value: insurace_value}, (error, result) => {
                console.log(error);
                callback(error, payload);
        });
    }

    updateFlightStatus(callback) {
        //Please don't blame me for web3.eth error of handling events:
        //Error: The current provider doesn't support subscriptions: HttpProvider
        this.flightSuretyApp.events.FlightStatusInfo({

            fromBlock: 0

        }, (error, ev) => {
            if (error) {

                console.log(error);

                callback(error);
            }

        }).on('data', e => {

            callback(null, e.returnValues);

        });
    }
}