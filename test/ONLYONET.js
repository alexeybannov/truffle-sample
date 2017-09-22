var ONLYONET = artifacts.require("ONLYONET");

const BigNumber = web3.BigNumber

const expect = require('chai')
               .use(require('chai-as-promised'))
               .use(require('chai-bignumber')(BigNumber)).expect;

contract('ONLYONET', function([_, owner, validator1, validator2, client1, client2]) {
    beforeEach(async function() {
        this.SYSTEM_ADDRESS = '0xc1cb2E15A2d6C8e47ee3909af601B69eF9309985';        
        this.instance = await ONLYONET.new();   
        
        await this.instance.initializeValidators();    
        await this.instance.finalizeChange({ from: this.SYSTEM_ADDRESS});
      }
    );

    it('should register client', async function() {
        let validators = await this.instance.getValidators.call();
        await this.instance.registerClient(client1, {from: validators[0] });
        let clientIsRegistred = await this.instance.registered.call(client1);
        expect(clientIsRegistred).to.be.true;
    });    

    it('should report stats', async function() {
        let data = "sample data string";
        let date = await this.instance.reportStatsDate.call();
        //  console.log(date);
        await this.instance.reportStats(client1, data); 
    });    
});