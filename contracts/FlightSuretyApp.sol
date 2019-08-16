pragma solidity ^0.4.25;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

//import FlightSuretyData
import "../contracts/FlightSuretyData.sol";


/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }
    mapping(bytes32 => Flight) private flights;

    //Added
    FlightSuretyData flightSuretyData;

    struct RegistrationInfo{
        uint256 totalVotes;
        bool success;
    }
    //total votes for airline to be registed, address is for an airline to be registered
    mapping(address => RegistrationInfo) public registrationInformations;

    //Is airline already voted for an airline to be registered?
    //e.g. voterVoted[toBeRegistedAirlineAddress][voterAirline]
    mapping(address => mapping(address => bool)) voterVoted;

    //Flights' passengers
    mapping(bytes32 => address[]) flightsPassengers;

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational()
    {
         // Modify to call data contract's status
        require(true, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
    * @dev Modifier that requires the function caller to be registered airline
    */
    modifier onlyRegisteredAirline()
    {
        require(flightSuretyData.isAirline(msg.sender),
                "Only registered airlines can perform this operation");
        _;
    }
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor (address dataContractAddress)
                                public
    {
        contractOwner = msg.sender;

        flightSuretyData = FlightSuretyData(dataContractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
                            public
                            view
                            returns(bool)
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline(address toBeRegistedAirlineAddress)
                            public
                            onlyRegisteredAirline
                            returns(bool success, uint256 votes)
    {
        success = false;
        require(flightSuretyData.isAirlineFunded(msg.sender),
            "Calling airline has no fund to register another airline.");
        
        require(!flightSuretyData.isAirline(toBeRegistedAirlineAddress),
            "Input airline is already registered");

        uint regAirlinesCs = flightSuretyData.getRegisteredAirlinesCount();

        //Only existing airline may register a new airline until there are at least four airlines registered
        if(regAirlinesCs<4){
            flightSuretyData.registerAirline(toBeRegistedAirlineAddress);
            success = true;
            return (success, 0);
        } else
        //Registration of fifth and subsequent airlines requires multi-party consensus of 50% of registered airlines
        {
            address voterAirline = msg.sender;

            require(!voterVoted[toBeRegistedAirlineAddress][voterAirline],"Voter already voted.");
            voterVoted[toBeRegistedAirlineAddress][voterAirline] = true;

            registrationInformations[toBeRegistedAirlineAddress].totalVotes++;
            
            uint votingPercentage = regAirlinesCs/2;
            //multi-party consensus of 50% of registered airlines
            if(registrationInformations[toBeRegistedAirlineAddress].totalVotes >= votingPercentage){
                flightSuretyData.registerAirline(toBeRegistedAirlineAddress);
                registrationInformations[toBeRegistedAirlineAddress].success = true;//Airline is registed return success true
            }

            return (registrationInformations[toBeRegistedAirlineAddress].success,
                registrationInformations[toBeRegistedAirlineAddress].totalVotes);
        }
    }


   /**
    * @dev Airline registers a future flight for insuring.
    *
    */
    function registerFlight(string flight,
                            uint256 flightTime)
                            external
                            onlyRegisteredAirline
    {
        bytes32 flightKey = getFlightKey(msg.sender, flight, flightTime);

        require(!flights[flightKey].isRegistered,"Flight already registered");

        flights[flightKey] = Flight(true, STATUS_CODE_UNKNOWN, flightTime, msg.sender);
    }


    /**
    * @dev Passengers may pay up to 1 ether for purchasing flight insurance.
    *
    */
    function purchageFlightInsurance(
                                    address airline,
                                    string flight,
                                    uint256 timestamp
                                )
                                external
                                payable
    {
        require(!flightSuretyData.isAirline(msg.sender),"Airline cannot purchase insurance.");

        require(msg.value <= 1 ether, "flight insurance cannot be more than 1 ether.");

        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        flightSuretyData.buyInsurance(flightKey);
    }

    /**
    * @dev Passenger Repayment
    * If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid
    *
    */
    function creditPayout(
                            bytes32 flightKey,
                            address passengerAddress
                        )
                                private
    {
        uint256 payout = flightSuretyData.getPurchasedInsurance(flightKey) * 15 / 10;

        flightSuretyData.payoutInsurance.value(payout)(flightKey,passengerAddress);
    }

    function withdrawPayout(
                                    address airline,
                                    string flight,
                                    uint256 timestamp
                                )
                                external
                                payable
    {
        require(!flightSuretyData.isAirline(msg.sender),"Airline cannot purchase insurance.");

        require(msg.value <= 1 ether, "flight insurance cannot be more than 1 ether.");

        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        flightSuretyData.withdrawInsurance(flightKey);
    }

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus
                                (
                                    address airline,
                                    string flight,
                                    uint256 timestamp,
                                    uint8 statusCode
                                )
                                internal
                                onlyRegisteredAirline
    {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        require(flights[flightKey].isRegistered,"Flight not registered.");

        flights[flightKey].statusCode = statusCode;

        //If flight is delayed due to airline fault, passenger receives credit of 1.5X the amount they paid
        if(STATUS_CODE_LATE_AIRLINE == statusCode){
            //add credit for each passenger
            for(uint256 i = 0; i<flightsPassengers[flightKey].length; i++){
                creditPayout(flightKey,flightsPassengers[flightKey][i]);
            }
        }
    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

        emit OracleRequest(index, airline, flight, timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle
                            (
                            )
                            external
                            payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    function getMyIndexes
                            (
                            )
                            view
                            external
                            returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse
                        (
                            uint8 index,
                            address airline,
                            string flight,
                            uint256 timestamp,
                            uint8 statusCode
                        )
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) ||
         (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");


        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
                            (
                                address account
                            )
                            internal
                            returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
                            (
                                address account
                            )
                            internal
                            returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}