pragma solidity ^0.4.25;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false

    //Airlines
    struct Airline{
        bool isRegistered;
        bool isFunded;
    }

    uint registeredAirlinesCount;
    mapping(address => Airline) airlines;

    struct FlightInsurace{
        uint256 purchased;
        uint256 redeemed;
    }

    mapping(bytes32 => mapping(address => FlightInsurace)) public passengersInsurances;

    //Authorized app contracts
    mapping(address => bool) authorizedAppContracts;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor
                                (
                                    address firstAirline
                                )
                                public
    {
        contractOwner = msg.sender;

        //Add first airline when contract is deployed
        airlines[firstAirline].isRegistered = true;
        registeredAirlinesCount = 1;
    }

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
        require(operational, "Contract is currently not operational");
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

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Authorize App contract
    *
    */
    function authorizeCaller(address appContractAddress)
        external
        requireContractOwner
    {
        authorizedAppContracts[appContractAddress] = true;
    }

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */
    function isOperational()
                            public
                            view
                            returns(bool)
    {
        return operational;
    }

    /**
    * @dev Get is the airline registered
    *
    * @return A bool that is the current operating status
    */
    function isAirline(address airlineAddress)
                            public
                            view
                            returns(bool)
    {
        return airlines[airlineAddress].isRegistered;
    }

    /**
    * @dev Get is the airline funded
    *
    * @return A bool that is the current operating status
    */
    function isAirlineFunded(address airlineAddress)
                            public
                            view
                            returns(bool)
    {
        return airlines[airlineAddress].isFunded;
    }

    /**
    * @dev Returns registered airlines count
    *
    * @return uint
    */
    function getRegisteredAirlinesCount()
                            public
                            view
                            returns(uint)
    {
        return registeredAirlinesCount;
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus
                            (
                                bool mode
                            )
                            external
                            requireContractOwner
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */
    function registerAirline
                            (
                                address airlineAddress
                            )
                            external
    {
        //Add airline
        airlines[airlineAddress].isRegistered = true;
        registeredAirlinesCount++;
    }

    /**
    * @dev Fund an airline to be able to perform the operations
    *
    */
    function fundAirline(address airlineAddress) external payable
    {
        require(msg.value==10,"Funds amount has to be 10 ether.");
        require(!airlines[airlineAddress].isFunded,"Airline already funded.");

        airlines[airlineAddress].isFunded = true;
    }

    function buyInsurance(bytes32 flightKey) external payable
    {
        passengersInsurances[flightKey][msg.sender].purchased = msg.value;
    }

    function payoutInsurance(bytes32 flightKey, address passenger) external payable
    {
        passengersInsurances[flightKey][passenger].redeemed = msg.value;
    }

    function withdrawInsurance(bytes32 flightKey) external payable
    {
        uint256 v = passengersInsurances[flightKey][msg.sender].redeemed;

        require(v>0,"No insurance to transfer.");

        msg.sender.transfer(v);
    }

    function getPurchasedInsurance(bytes32 flightKey)
                            public
                            view
                            returns(uint256)
    {
        return passengersInsurances[flightKey][msg.sender].purchased;
    }

//    /**
//     * @dev Buy insurance for a flight
//     *
//     */
//     function buy
//                             (
//                             )
//                             external
//                             payable
//     {

//     }

//     /**
//      *  @dev Credits payouts to insurees
//     */
//     function creditInsurees
//                                 (
//                                 )
//                                 external
//                                 pure
//     {
//     }


//     /**
//      *  @dev Transfers eligible payout funds to insuree
//      *
//     */
//     function pay
//                             (
//                             )
//                             external
//                             pure
//     {
//     }

//    /**
//     * @dev Initial funding for the insurance. Unless there are too many delayed flights
//     *      resulting in insurance payouts, the contract should be self-sustaining
//     *
//     */
//     function fund
//                             (
//                             )
//                             public
//                             payable
//     {
//     }

    function getFlightKey
                        (
                            address airline,
                            string memory flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // /**
    // * @dev Fallback function for funding smart contract.
    // *
    // */
    // function()
    //                         external
    //                         payable
    // {
    //     fund();
    // }


}

