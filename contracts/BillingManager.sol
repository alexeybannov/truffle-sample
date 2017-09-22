pragma solidity ^0.4.11;

contract BillingManager {   

    event ReportOrder(address indexed client, address indexed seller, uint256 orderId);
    mapping(address => Order[]) orders;

    struct Order {
        address seller;
        address client;
        uint256 date;
    }

    function submitOrder(address _client, address _seller) {
        require(_client != 0x0);
        require(_seller != 0x0);
  
        uint256 count = orders[_client].push(Order({
            seller:_seller,
            client:_client,
            date: now
        }));

        ReportOrder(_seller, _client, count - 1);            
    }

    function getOrder(address _client, uint256 _orderId) constant returns (address seller, uint256 date)  {
        require(_client != 0x0);
        require(_orderId > 0);

        seller = orders[_client][_orderId].seller;
        date = orders[_client][_orderId].date;  

    }  

     // Fallback function throws when called.
    function() {
        revert();
    }  
}