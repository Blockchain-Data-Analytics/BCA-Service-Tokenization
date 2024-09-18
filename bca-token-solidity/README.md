# BCA Token

## setup

npx hardhat init

(npm install @openzeppelin/contracts)

npx hardhat compile

REPORT_GAS=true npx hardhat test --typecheck

> run a node locally:
npx hardhat node


# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a Hardhat Ignition module that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat ignition deploy ./ignition/modules/Lock.ts
```

GAS estimation:
```
·-----------------------------------------|---------------------------|--------------|-----------------------------·
|          Solc version: 0.8.24           ·  Optimizer enabled: true  ·  Runs: 1000  ·  Block limit: 30000000 gas  │
··········································|···························|··············|······························
|  Methods                                                                                                         │
····················|·····················|·············|·············|··············|···············|··············
|  Contract         ·  Method             ·  Min        ·  Max        ·  Avg         ·  # calls      ·  usd (avg)  │
····················|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken  ·  burn               ·      31869  ·      36669  ·       34269  ·            4  ·          -  │
····················|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken  ·  mint               ·          -  ·          -  ·       70820  ·            7  ·          -  │
····················|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken  ·  setServiceAddress  ·          -  ·          -  ·       54526  ·            2  ·          -  │
····················|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken  ·  transfer           ·      36668  ·      53780  ·       45224  ·            6  ·          -  │
····················|·····················|·············|·············|··············|···············|··············
|  Deployments                            ·                                          ·  % of limit   ·             │
··········································|·············|·············|··············|···············|··············
|  BCAServiceToken                        ·          -  ·          -  ·     1062016  ·        3.5 %  ·          -  │
·-----------------------------------------|-------------|-------------|--------------|---------------|-------------·
```
