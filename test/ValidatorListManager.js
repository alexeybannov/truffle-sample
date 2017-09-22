import advanceToBlock from '../helpers/advanceToBlock';
var ValidatorListManager = artifacts.require("ValidatorListManager");

const BigNumber = web3.BigNumber

const expect = require('chai')
               .use(require('chai-as-promised'))
               .use(require('chai-bignumber')(BigNumber)).expect;

contract('ValidatorListManager', function([_, owner, validator1, validator2]) {
    beforeEach(async function() {
        this.SYSTEM_ADDRESS = '0xc1cb2E15A2d6C8e47ee3909af601B69eF9309985';        
        this.instance = await ValidatorListManager.new();   
        
        await this.instance.initializeValidators();    
        await this.instance.finalizeChange({ from: this.SYSTEM_ADDRESS});
      }
    );

    it('should ignore misbehaviour older than number of blocks.. ', async function() {
        let validators = await this.instance.getValidators.call();
        const indexToRemove = 1;
        const index = 0;
        
        const RECENT_BLOCKS = (await this.instance.RECENT_BLOCKS.call()).toNumber();
        
        await advanceToBlock(web3.eth.blockNumber + RECENT_BLOCKS + 1);
        
        let benignBlock = web3.eth.blockNumber - RECENT_BLOCKS - 1;
        
        expect(this.instance.reportBenign(validators[indexToRemove], benignBlock, {from: validators[index]})).to.be.rejected;
        
        benignBlock = web3.eth.blockNumber - RECENT_BLOCKS + 2 ;

        expect(this.instance.reportBenign(validators[indexToRemove], benignBlock, {from: validators[index]})).to.be.fulfilled;
    });

    it('should time after which the validators will report a validator as malicious.', async function() {
        let validators = await this.instance.getValidators.call();
        const indexToRemove = 1;
        const index = 0;
        const RECENT_BLOCKS = (await this.instance.RECENT_BLOCKS.call()).toNumber();
        await advanceToBlock(web3.eth.blockNumber + RECENT_BLOCKS + 1);
        let benignBlock = web3.eth.blockNumber - RECENT_BLOCKS + 2;

        let repeatedBenign = (await this.instance.getRepeatedBenign.call(validators[indexToRemove])).toNumber();
        
        await this.instance.reportBenign(validators[indexToRemove], benignBlock, {from: validators[index]});
        await this.instance.reportBenign(validators[indexToRemove], benignBlock, {from: validators[index]});
        
        let newRepeatedBenign = (await this.instance.getRepeatedBenign.call(validators[indexToRemove])).toNumber();
        
        expect(repeatedBenign).to.be.eql(newRepeatedBenign);
 
        const addSeconds=(((await this.instance.MAX_INACTIVITY.call()).toNumber())+1)*60*60; // 7 hours 
        
        web3.currentProvider.send({jsonrpc: "2.0", method: "evm_increaseTime", params: [addSeconds], id: 0})
      
        benignBlock = web3.eth.blockNumber - RECENT_BLOCKS + 2;
        
        await this.instance.reportBenign(validators[indexToRemove], benignBlock, {from: validators[index]});
        
        newRepeatedBenign = (await this.instance.getRepeatedBenign.call(validators[indexToRemove])).toNumber();
        
        expect(repeatedBenign+1).to.be.eql(newRepeatedBenign);        
    });

    it('should remove the validator if low supported by majority. ', async function() {
         let validators = await this.instance.getValidators.call();
         let maliciousBlock = web3.eth.blockNumber;

         await advanceToBlock(maliciousBlock + 10);
         
         let indexToRemove = 0;

         let support = await this.instance.getSupport.call(validators[indexToRemove]);
         let supported = await this.instance.getSupported.call(validators[parseInt(validators.length/2)]);
         
         for (let index = 0; index < validators.length/2+1; index++) {
            if (indexToRemove == index) continue;

            await this.instance.reportMalicious(validators[indexToRemove], maliciousBlock, "", {from: validators[index]});
         }

         let newSupported = await this.instance.getSupported.call(validators[parseInt(validators.length/2)]);
         let newSupport = await this.instance.getSupport.call(validators[indexToRemove]);

         expect(parseInt(validators.length/2) - 1).to.be.eql(newSupport.toNumber());
         expect(supported.length-1).to.be.eql(newSupported.length);
         
         await this.instance.finalizeChange({ from: this.SYSTEM_ADDRESS});

         let actualValidators = Array.from(validators);

         actualValidators[indexToRemove] = actualValidators[actualValidators.length-1];         
         actualValidators.pop();

         let newValidators = await this.instance.getValidators.call();
        
         expect(newValidators).to.deep.equal(actualValidators);
         
    });

    it('should remove the validator if supported by majority.', async function() {
        let validators = await this.instance.getValidators.call();
        let benignBlock = web3.eth.blockNumber-1;
        let indexToRemove = 0;
    
        let startedSupport = await this.instance.getSupport.call(validators[indexToRemove]);
        
//        console.log("Support %d for '%s' validator in %d block", startedSupport.toNumber(), validators[indexToRemove], web3.eth.blockNumber);
        
        for (let index = 0; index < validators.length; index++) {
            if (indexToRemove == index) continue;
           
            let validator = validators[index];
            await this.instance.reportBenign(validators[indexToRemove], benignBlock, { from: validator });
        }
        
        let support = await this.instance.getSupport.call(validators[indexToRemove]);
        
 //       console.log("Support %d for '%s' validator in %d block", support.toNumber(), validators[indexToRemove], web3.eth.blockNumber);

        let repeatedBenign = await this.instance.getRepeatedBenign.call(validators[indexToRemove]);
        
   //     console.log("RepeatedBenign %d for validator %s in block %d timestamp %d",repeatedBenign.toNumber(), validators[indexToRemove], web3.eth.blockNumber, web3.eth.getBlock(web3.eth.blockNumber).timestamp);
        
        const addSeconds=7*60*60; // 7 hours

        web3.currentProvider.send({jsonrpc: "2.0", method: "evm_increaseTime", params: [addSeconds], id: 0})
        
        for (let index = 0; index < validators.length/2+1; index++) {
            if (indexToRemove == index) continue;
           
            let validator = validators[index];

            await this.instance.reportBenign(validators[indexToRemove], web3.eth.blockNumber - 15, { from: validator });
            
            let repeatedBenign = await this.instance.getRepeatedBenign.call(validators[indexToRemove]);

 //           console.log("RepeatedBenign %d for validator %s in block %d timestamp %d",repeatedBenign.toNumber(), validators[indexToRemove], web3.eth.blockNumber, web3.eth.getBlock(web3.eth.blockNumber).timestamp);

        }

        let endedSupport = await this.instance.getSupport.call(validators[indexToRemove]);
        
  //      console.log("Support %d for '%s' validator in %d block", endedSupport.toNumber(), validators[indexToRemove], web3.eth.blockNumber);
        
        expect(startedSupport.minus(1)).to.be.bignumber.equal(endedSupport);
    });

    it('should return the correct validatorsList after construction', async function () {
        let validatorsList = await this.instance.getValidators.call();
        expect(validatorsList.length).to.be.equal(9);
    });

    it('should vote to include a validator', async function ()  {
        let validators = await this.instance.getValidators.call();

        for (let index = 0; index < validators.length/2-1; index++) {
            let validator = validators[index];
            await this.instance.addSupport(validator1, { from: validator });        
            let supported = await this.instance.getSupported.call(validator);
                        
            expect(supported).to.deep.equal(validators.concat([validator1]));
        }
        
        let support = await this.instance.getSupport.call(validator1);

        expect(support).to.be.bignumber.equal(new BigNumber(parseInt(validators.length/2) ));      

    });

     it('should add the validator if supported by majority.', async function() {
        let validators = await this.instance.getValidators.call();

        for (let index = 0; index < validators.length/2; index++) {
            let validator = validators[index];
            await this.instance.addSupport(validator1, { from: validator });        
        }
     
        await this.instance.finalizeChange({ from: this.SYSTEM_ADDRESS});
        
        let newValidators = await this.instance.getValidators.call();
        
        expect(newValidators).to.deep.equal(validators.concat([validator1]));

     });
});