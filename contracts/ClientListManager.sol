pragma solidity ^0.4.11;

contract ClientListManager {   
    address[] public clients;
    mapping(address => ClientStatus) clientStatus;
    uint256 public reportStatsDate = now;
  
    struct ClientStatus {
          bool isRegistered;
          bool isEnabled;      
    }

    event ReportStats(address indexed client, string stats);

    function registered(address _client) constant returns (bool) {
        require(_client != 0x0);

        return clientStatus[_client].isRegistered;
    }

    function registerClient(address _client) is_not_registered(_client) {
        require(_client != 0x0);

        clients.push(_client);

        clientStatus[_client] = ClientStatus({
            isRegistered: true,
            isEnabled: true
        });
    }

    function enabled(address _client) constant returns (bool) {
        require(_client != 0x0);

        return clientStatus[_client].isEnabled;
    }   

    function restrictAccess(address _client) is_registered(_client) {
        require(_client != 0x0);

        clientStatus[_client].isEnabled = false;
    }

    function reportStats(address _client, string _stats) is_not_registered(_client) {
        require(_client != 0x0);
        require(bytes(_stats).length > 0);

        ReportStats(_client, _stats);

        reportStatsDate=now;
    }
  
    modifier is_not_registered(address _client) {
        require(!registered(_client));
        _;
    }

    modifier is_registered(address _client) {
        require(registered(_client));
        _;
    }

    // Fallback function throws when called.
    function() {
        revert();
    }
}