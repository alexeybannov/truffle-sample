pragma solidity ^0.4.11;

library AddressSet {
    // Tracks the number of votes from different addresses.
    struct Data {
        uint count;
        // Keeps track of who voted, prevents double vote.
        mapping(address => bool) inserted;
    }

    function count(Data storage self) constant returns (uint) {
        return self.count;
    }

    function contains(Data storage self, address voter) returns (bool) {
        return self.inserted[voter];
    }

    function insert(Data storage self, address voter) returns (bool) {
        if (self.inserted[voter]) { return false; }
        self.count++;
        self.inserted[voter] = true;
        return true;
    }

    function remove(Data storage self, address voter) returns (bool) {
        if (!self.inserted[voter]) { return false; }
        self.count--;
        self.inserted[voter] = false;
        return true;
    }
}