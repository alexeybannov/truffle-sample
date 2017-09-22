pragma solidity ^0.4.8;

contract ReportingValidatorSet  {
    event InitiateChange(bytes32 indexed _parent_hash, address[] _new_set);

    function getValidators() constant returns (address[] _validators);
    function finalizeChange();

    // Reporting functions: operate on current validator set.
    // malicious behavior requires proof, which will vary by engine.
    function reportBenign(address validator, uint256 blockNumber);
    function reportMalicious(address validator, uint256 blockNumber, bytes proof);
}