pragma solidity ^0.4.11;

contract LicenseManager  {        
    mapping (address => License) licenses;

    event LicenseGenerate(address indexed client, uint256 _portal_count, uint256 _start_date, uint256 _end_date);

    function LicenseManager() {
        
    }

    struct License {
        address client;
        uint256 portal_count;
        uint256 start_date;        
        uint256 end_date;
        bool isActivated;        
    }

    function licenseGenerate(address _client, 
                             uint256 _portal_count, 
                             uint256 _start_date, 
                             uint256 _end_date)  {

        require(_client != 0x0);
        require(_portal_count > 0);
        require(_start_date > 0);
        require(_end_date > 0);
        

        licenses[_client] = License({
            client: _client,
            portal_count: _portal_count,
            start_date: _start_date,
            end_date: _end_date,
            isActivated: true
        });

        LicenseGenerate(_client, _portal_count, _start_date, _end_date);
    }

    function getLicense(address _client) constant returns(uint256 _portal_count, uint256 _start_date, uint256 _end_date) {
        require(_client != 0x0);

        return (licenses[_client].portal_count, licenses[_client].start_date, licenses[_client].end_date);
    }

    function isPaid(address _client) constant returns (bool) {
        require(_client != 0x0);
        
        return licenses[_client].isActivated;
    }

    // Fallback function throws when called.
    function() {
        revert();
    }
}