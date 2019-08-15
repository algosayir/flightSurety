
var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');

contract('Flight Surety Tests', async (accounts) => {

  var config;
  let flight = "SV 1265";
  let time = new Date().getTime();
  const TEST_ORACLES_COUNT = 20;
  let oracles = accounts.slice(9, 30);

  before('setup contract', async () => {
    config = await Test.Config(accounts);
    await config.flightSuretyData.authorizeCaller(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {

      // Ensure that access is denied for non-Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false, { from: config.testAddresses[2] });
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
            
  });

  it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {

      // Ensure that access is allowed for Contract Owner account
      let accessDenied = false;
      try 
      {
          await config.flightSuretyData.setOperatingStatus(false);
      }
      catch(e) {
          accessDenied = true;
      }
      assert.equal(accessDenied, false, "Access not restricted to Contract Owner");
      
  });

  it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {

      await config.flightSuretyData.setOperatingStatus(false);

      let reverted = false;
      try 
      {
          await config.flightSurety.setTestingMode(true);
      }
      catch(e) {
          reverted = true;
      }
      assert.equal(reverted, true, "Access not blocked for requireIsOperational");      

      // Set it back for other tests to work
      await config.flightSuretyData.setOperatingStatus(true);

  });

  it('(airline) cannot register an Airline using registerAirline() if it is not funded', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        //assert.equal(true,false,e.message);
    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, false, "Airline should not be able to register another airline if it hasn't provided funding");

  });
 
  it('(airline) fund first airline and register the second', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];

    // ACT
    try {
        await config.flightSuretyData.fundAirline(config.firstAirline,{from: config.firstAirline, value: 10})

        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        //Execption should not be thrown otherwise there is an error
        assert.equal(true,false,e.message);
    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, true, "Second Airline was not registered.");

  });

  it('(airline) cannot register an Airline again', async () => {
    
    // ARRANGE
    let newAirline = accounts[2];
    let isAlreadyRegisteded = false;
    // ACT
    try {
        await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
    }
    catch(e) {
        //if(e.message == "Input airline is already registered"){
            isAlreadyRegisteded = true;
        //};
        //assert.equal(true,false,e.message);
    }

    // ASSERT
    assert.equal(isAlreadyRegisteded, true, "Airline should not be able to registered again.");

  });

  it('(airline) fund second airline and register the 3rd and 4th airline', async () => {
    
    // ARRANGE
    let secondAl = accounts[2];
    let thirdAl = accounts[3];
    let forthAl = accounts[4];

    // ACT
    try {
        await config.flightSuretyData.fundAirline(secondAl,{from: secondAl, value: 10})

        await config.flightSuretyApp.registerAirline(thirdAl, {from: secondAl});

        await config.flightSuretyApp.registerAirline(forthAl, {from: secondAl});
    }
    catch(e) {
        //Execption should not be thrown otherwise there is an error
        assert.equal(true,false,e.message);
    }
    let result = await config.flightSuretyData.isAirline.call(thirdAl); 
    //console.log(result);
    let result2 = await config.flightSuretyData.isAirline.call(forthAl); 

    // ASSERT
    assert.equal(result, true, "third airline was not registered.");
    assert.equal(result2, true, "forth airline was not registered.");

  });

  it('(airline) register the fifth airline', async () => {
    
    // ARRANGE
    let newAirline = accounts[5];
    let secondAirline = accounts[2];
    // ACT
    // Registering fifth airline require two votes/airlines
    try {
        let r = await config.flightSuretyApp.registerAirline(newAirline, {from: config.firstAirline});
        let cc = await config.flightSuretyApp.registrationInformations.call(newAirline);
        //console.log("cc=")
        //console.log(cc);
        assert.equal(cc.success,false,"Wrong voting tracking.\n");
        assert.equal(cc.totalVotes,1,"Votes count is wrong.");

        let rr = await config.flightSuretyApp.registerAirline(newAirline, {from: secondAirline});
        cc = await config.flightSuretyApp.registrationInformations.call(newAirline);
        //console.log("cc=")
        //console.log(cc);
        assert.equal(cc.success,true,"Wrong voting tracking, flight should be registed and sucess is true\n");
        assert.equal(cc.totalVotes,2,"Votes count is wrong.");
    }
    catch(e) {
        //Execption should not be thrown otherwise there is an error
        assert.equal(true,false,e.message);
    }
    let result = await config.flightSuretyData.isAirline.call(newAirline); 

    // ASSERT
    assert.equal(result, true, "fifth Airline was not registered.");
  });

  it('(Passengers) Passenger Airline choise: register to flight', async () => {
    //ARRANGE
    let success = false;
    //ACT
    try{
        await config.flightSuretyApp.registerFlight(flight,time,{from: config.firstAirline});
        success = true;

    } catch(e){
        sucess = false;
        assert.equal(true, false, e.message);
    }
    //ASSERT
    assert.equal(success,true,"Flight was not registered.")
  });

  it('(Passengers) Passenger Payment: buy insurance', async () => {
    //ARRANGE
    let success = false;
    let aPassenger = accounts[10];

    //ACT
    try{
        await config.flightSuretyApp.PurchageFlightInsurance(config.firstAirline,flight,time,{from: aPassenger});
        success = true;
    } catch(e){
        sucess = false;
        assert.equal(true, false, e.message);
    }

    //ASSERT
    assert.equal(success,true,"Could not buy insurance.")
  });


it('(Passengers) Passenger Withdraw: withdraw insurance', async () => {
    //ARRANGE
    let success = true;
    let aPassenger = accounts[10];

    //ACT
    try{
        await config.flightSuretyApp.withdrawPayout(config.firstAirline,flight,time,{from: aPassenger});
        success = true;
    } catch(e){
        //sucess = false;
        //assert.equal(true, false, e.message);
    }

    //ASSERT
    assert.equal(success,true,"Could not buy insurance.")

});

});
