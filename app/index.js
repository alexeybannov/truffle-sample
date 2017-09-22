import { default as Web3} from 'web3';
import { default as contract } from 'truffle-contract';
import onlyonet_artifacts from '../build/contracts/ONLYONET.json'

var provider = new Web3.providers.HttpProvider("http://localhost:8545");
var ONLYONET = contract(onlyonet_artifacts);
const ONLYONET_ADDRESS = "0xed7f7effd369a16746a7955dc18235f13b31928d";

var contractInstance = ONLYONET.at(ONLYONET_ADDRESS);

var mysql = require('mysql');

contractInstance.

var connection = mysql.createConnection({
    host     : 'localhost',
    user     : 'root',
    password : '111111',
    database : 'teamlab'
});

connection.query('SELECT * FROM audit_events limit 2;', function (error, results, fields) {
    if (error) throw error;

    var logs = [];

    for (var rowIndex = 0; rowIndex < results.length; rowIndex++) {
        var row = results[rowIndex];
        
        var rowData = {
            id: row.id,
            ip: row.ip,
            initiator: row.initiator,
            browser: row.browser,
            platform: row.platform,
            date: row.date,
            tenant_id: row.tenant_id,
            user_id: row.user_id,
            page: row.page,
            action: row.action,
            description: row.description
        };

        logs.push(rowData);

        var temp = JSON.stringify(logs);
    }
});

connection.end(function(err) {    
    // The connection is terminated now
});