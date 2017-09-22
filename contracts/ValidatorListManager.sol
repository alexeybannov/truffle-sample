pragma solidity ^0.4.11;

import './AddressSet.sol';
import './ReportingValidatorSet.sol';

// Existing validators can give support to addresses.
// Support can not be added once MAX_VALIDATORS are present.
// Once given, support can be removed.
// Addresses supported by more than half of the existing validators are the validators.
// Malicious behaviour causes support removal.
// Benign misbehaviour causes supprt removal if its called again after MAX_INACTIVITY.
// Benign misbehaviour can be absolved before being called the second time.
contract ValidatorListManager is ReportingValidatorSet {

    // EVENTS

    event Report(address indexed reporter, address indexed reported, bool indexed malicious, uint blockNumber);
    event Support(address indexed supporter, address indexed supported, bool indexed added);
    event ChangeFinalized(address[] current_set);

    struct ValidatorStatus {
        // Is this a validator.
        bool isValidator;
        // Index in the validatorList.
        uint index;
        // Validator addresses which supported the address.
        AddressSet.Data support;
        // Keeps track of the votes given out while the address is a validator.
        address[] supported;
        // Initial benign misbehaviour time tracker.
        mapping(address => uint) firstBenign;
        // Repeated benign misbehaviour counter.
        AddressSet.Data  benignMisbehaviour;
    }

    // System address, used by the block sealer.
    address SYSTEM_ADDRESS = 0xc1cb2E15A2d6C8e47ee3909af601B69eF9309985;
    // Support can not be added once this number of validators is reached.
    uint public constant MAX_VALIDATORS = 30;
    // Time after which the validators will report a validator as malicious.
    uint public constant MAX_INACTIVITY = 6 hours;
    // Ignore misbehaviour older than this number of blocks.
    uint public constant RECENT_BLOCKS = 20;

    // STATE

    // Current list of addresses entitled to participate in the consensus.
    address[] public validatorsList;
    // Pending list of validator addresses.
    address[] pendingList;
    // Was the last validator change finalized.
    bool finalized;
    // Tracker of status for each address.
    mapping(address => ValidatorStatus) validatorsStatus;

    // CONSTRUCTOR

    // Used to lower the constructor cost.
    AddressSet.Data initialSupport;
    bool private initialized;

    function ValidatorListManager() {
            
    }

    // Each validator is initially supported by all others.
    // Has to be called once before any other methods are called.
    function initializeValidators() uninitialized {
        pendingList = [
            // Etherscan
            0xE89A374cac938EbfeF73CeDF1e482EbeA18561E5,
            // Attores
            0xDC10B6F067249392DD9c24518540010Fc692a97f,
            // TenX (OneBit)
            0x9E1c72FE9Fdce5a6f506762d5d261c7E535e2CE8,
            // Melonport
            0x9F0943f1b92283C8e1412000Aab7a91887539601,
            // Parity
            0x07AAD6bA9A362D66eF2A963546fa0e428B35cEd3,
            // DigixGlobal
            0x2644233d780f4F3451D08646c0A3fD845A28395c,
            // Maker
            0x0B603b54235Dae86F27f803CcFbC4d64C9f1F5E8,
            // Aurel
            0xc1cb2E15A2d6C8e47ee3909af601B69eF9309985,
            // GridSingularity
            0xB74891F03501666449c7200c86E009A8367b2c3b
        ];


        for (uint j = 0; j < pendingList.length; j++) {
            address validator = pendingList[j];
            validatorsStatus[validator] = ValidatorStatus({
                isValidator: true,
                index: j,
                support: initialSupport,
                supported: pendingList,
                benignMisbehaviour: AddressSet.Data({ count: 0 })
            });


        validatorsStatus[validator].support.count = pendingList.length;

        for (uint i = 0; i < pendingList.length; i++) {
            address supporter = pendingList[i];
            validatorsStatus[validator].support.inserted[supporter] = true;
        }

        }
     
        initialized = true;
        validatorsList = pendingList;
        finalized = false;
    }
   
    // CONSENSUS ENGINE METHODS

    // Called on every block to update node validator list.
    function getValidators() constant returns (address[]) {
        return validatorsList;
    }

    // Log desire to change the current list.
    function initiateChange() private when_finalized {
        finalized = false;
        InitiateChange(block.blockhash(block.number - 1), pendingList);
    }

    function finalizeChange() only_system_and_not_finalized {
        validatorsList = pendingList;
        finalized = true;
        ChangeFinalized(validatorsList);
    }

    // SUPPORT LOOKUP AND MODIFICATION

    // Find the total support for a given address.
    function getSupport(address validator) constant returns (uint) {
        return AddressSet.count(validatorsStatus[validator].support);
    }

    function getSupported(address validator) constant returns (address[]) {
        return validatorsStatus[validator].supported;
    }

    // Vote to include a validator.
    function addSupport(address validator) only_validator not_voted(validator) free_validator_slots {
        newStatus(validator);
        AddressSet.insert(validatorsStatus[validator].support, msg.sender);
        validatorsStatus[msg.sender].supported.push(validator);
        addValidator(validator);
        Support(msg.sender, validator, true);
    }

    // Remove support for a validator.
    function removeSupport(address sender, address validator) private   {
        if (!AddressSet.remove(validatorsStatus[validator].support, sender)) { revert(); }

        for (uint i = 0; i < validatorsStatus[sender].supported.length; i++) {
            if (validatorsStatus[sender].supported[i] == validator)
            {
                uint removedIndex = i;
                uint lastIndex = validatorsStatus[sender].supported.length - 1;
                address lastValidator = validatorsStatus[sender].supported[lastIndex];

                validatorsStatus[sender].supported[removedIndex] = lastValidator;

                delete validatorsStatus[sender].supported[lastIndex];
                
                validatorsStatus[sender].supported.length--;

                break;
            }            
         }
       
        Support(sender, validator, false);
        // Remove validator from the list if there is not enough support.
        removeValidator(validator);
    }

    // MALICIOUS BEHAVIOUR HANDLING

    // Called when a validator should be removed.
    function reportMalicious(address validator, uint blockNumber, bytes proof) only_validator is_recent(blockNumber) {
        removeSupport(msg.sender, validator);
        Report(msg.sender, validator, true, blockNumber);
    }

    // BENIGN MISBEHAVIOUR HANDLING

    // Report that a validator has misbehaved in a benign way.
    function reportBenign(address validator, uint blockNumber) only_validator is_validator(validator) is_recent(blockNumber) {
        firstBenign(validator);
        repeatedBenign(validator);
        Report(msg.sender, validator, false, blockNumber);
    }

    // Find the total number of repeated misbehaviour votes.
    function getRepeatedBenign(address validator) constant returns (uint) {
        return AddressSet.count(validatorsStatus[validator].benignMisbehaviour);
    }

    // Track the first benign misbehaviour.
    function firstBenign(address validator) private has_not_benign_misbehaved(validator) {
        validatorsStatus[validator].firstBenign[msg.sender] = now;
    }

    // Report that a validator has been repeatedly misbehaving.
    function repeatedBenign(address validator) private has_repeatedly_benign_misbehaved(validator) {
        AddressSet.insert(validatorsStatus[validator].benignMisbehaviour, msg.sender);
        confirmedRepeatedBenign(validator);
    }

    // When enough long term benign misbehaviour votes have been seen, remove support.
    function confirmedRepeatedBenign(address validator) private agreed_on_repeated_benign(validator) {
        validatorsStatus[validator].firstBenign[msg.sender] = 0;
        AddressSet.remove(validatorsStatus[validator].benignMisbehaviour, msg.sender);
        removeSupport(msg.sender, validator);
    }

    // Absolve a validator from a benign misbehaviour.
    function absolveFirstBenign(address validator) has_benign_misbehaved(validator) {
        validatorsStatus[validator].firstBenign[msg.sender] = 0;
        AddressSet.remove(validatorsStatus[validator].benignMisbehaviour, msg.sender);
    }

    // PRIVATE UTILITY FUNCTIONS

    // Add a status tracker for unknown validator.
    function newStatus(address validator) private has_no_votes(validator) {
        validatorsStatus[validator] = ValidatorStatus({
            isValidator: false,
            index: pendingList.length,
            support: AddressSet.Data({ count: 0 }),
            supported: new address[](0),
            benignMisbehaviour: AddressSet.Data({ count: 0 })
        });
    }

    // ENACTMENT FUNCTIONS (called when support gets out of line with the validator list)

    // Add the validator if supported by majority.
    // Since the number of validators increases it is possible to some fall below the threshold.
    function addValidator(address validator) is_not_validator(validator) has_high_support(validator) {
        validatorsStatus[validator].index = pendingList.length;
        pendingList.push(validator);
        validatorsStatus[validator].isValidator = true;
        // New validator should support itself.
        AddressSet.insert(validatorsStatus[validator].support, validator);
        validatorsStatus[validator].supported.push(validator);

        initiateChange();
    
    }

    // Remove a validator without enough support.
    // Can be called to clean low support validators after making the list longer.
    function removeValidator(address validator) is_validator(validator) has_low_support(validator) {
        uint removedIndex = validatorsStatus[validator].index;
        // Can not remove the last validator.
        uint lastIndex = pendingList.length-1;
        address lastValidator = pendingList[lastIndex];
        // Override the removed validator with the last one.
        pendingList[removedIndex] = lastValidator;
        // Update the index of the last validator.
        validatorsStatus[lastValidator].index = removedIndex;
        delete pendingList[lastIndex];
        pendingList.length--;
        // Reset validator status.
        validatorsStatus[validator].index = 0;
        validatorsStatus[validator].isValidator = false;
        // Remove all support given by the removed validator.
        address[] storage toRemove = validatorsStatus[validator].supported;
        for (uint i = 0; i < toRemove.length; i++) {
            removeSupport(validator, toRemove[i]);
        }
        delete validatorsStatus[validator].supported;
        initiateChange();
    }

    // MODIFIERS

    modifier uninitialized() {
        require(!initialized);
        _;
    }

    function highSupport(address validator) constant returns (bool) {
        return getSupport(validator) > pendingList.length/2;
    }

    function firstBenignReported(address reporter, address validator) constant returns (uint) {
        return validatorsStatus[validator].firstBenign[reporter];
    }

    modifier has_high_support(address validator) {
        if (highSupport(validator)) { _; }
    }

    modifier has_low_support(address validator) {
        if (!highSupport(validator)) { _; }
    }

    modifier has_not_benign_misbehaved(address validator) {
        if (firstBenignReported(msg.sender, validator) == 0) { _; }
    }

    modifier has_benign_misbehaved(address validator) {
        if (firstBenignReported(msg.sender, validator) > 0) { _; }
    }

    modifier has_repeatedly_benign_misbehaved(address validator) {
        if (now - firstBenignReported(msg.sender, validator) > MAX_INACTIVITY) { _; }
    }

    modifier agreed_on_repeated_benign(address validator) {
        if (getRepeatedBenign(validator) > pendingList.length/2) { _; }
    }

    modifier free_validator_slots() {
        require(pendingList.length < MAX_VALIDATORS);
        _;
    }

    modifier only_validator() {
        require(validatorsStatus[msg.sender].isValidator);
        _;
    }

    modifier is_validator(address someone) {
        if (validatorsStatus[someone].isValidator) { _; }
    }

    modifier is_not_validator(address someone) {
        if (!validatorsStatus[someone].isValidator) { _; }
    }

    modifier not_voted(address validator) {
        require(!(AddressSet.contains(validatorsStatus[validator].support, msg.sender)));
        _;
    }

    modifier has_no_votes(address validator) {
        if (AddressSet.count(validatorsStatus[validator].support) == 0) { _; }
    }

    modifier is_recent(uint blockNumber) {
        require(block.number <= blockNumber + RECENT_BLOCKS);
        _;
    }

    modifier only_system_and_not_finalized() {
        require(!(msg.sender != SYSTEM_ADDRESS || finalized));
        _;
    }

    modifier when_finalized() {
        require(finalized);
        _;
    }

    // Fallback function throws when called.
    function() {
        revert();
    }
}