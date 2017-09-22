pragma solidity ^0.4.11;

import './BillingManager.sol';
import './LicenseManager.sol';
import './ClientListManager.sol';
import './ValidatorListManager.sol';

contract ONLYONET is ValidatorListManager, ClientListManager, LicenseManager, BillingManager  {
    function registerClient(address _client) is_not_registered(_client) only_validator {
        super.registerClient(_client);
    }    

   function restrictAccess(address _client) is_registered(_client) only_validator {
        super.restrictAccess(_client);
   }
   
   function submitOrder(address _client, address _seller) is_registered(_client) is_validator(_seller) only_validator {
        super.submitOrder(_client, _seller);
   }
}