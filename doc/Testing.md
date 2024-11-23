# Testing

Tests are implemented in [bca-token-solidity/test](./bca-token-solidity/test/) and can be run:

```sh
cd bca-token-solidity
npx hardhat test
```

# Test coverage

How much of the contract's code is covered by tests? This can be answered by:

```sh
cd bca-token-solidity
npx hardhat coverage
```

Which outputs as of today (2024-11-23):

```sh
------------------------------|----------|----------|----------|----------|----------------|
File                          |  % Stmts | % Branch |  % Funcs |  % Lines |Uncovered Lines |
------------------------------|----------|----------|----------|----------|----------------|
 contracts/                   |    88.66 |    71.82 |    89.29 |    91.37 |                |
  BCA_ERC20_nf.sol            |      100 |    68.75 |      100 |      100 |                |
  BCA_Funding24.sol           |    84.62 |    81.25 |      100 |    88.89 |          64,66 |
  BCA_Service.sol             |       25 |       25 |    33.33 |    46.15 |... 45,48,50,54 |
  BCA_ServiceController.sol   |    85.71 |       50 |    66.67 |    88.89 |             43 |
  BCA_ServiceInstance.sol     |    95.45 |    81.48 |      100 |    96.97 |        141,171 |
  BCA_ServiceManager.sol      |      100 |       60 |      100 |      100 |                |
  Iface_Funding24.sol         |      100 |      100 |      100 |      100 |                |
  Iface_Service.sol           |      100 |      100 |      100 |      100 |                |
  Iface_ServiceController.sol |      100 |      100 |      100 |      100 |                |
  Iface_ServiceInstance.sol   |      100 |      100 |      100 |      100 |                |
  Iface_ServiceManager.sol    |      100 |      100 |      100 |      100 |                |
------------------------------|----------|----------|----------|----------|----------------|
All files                     |    88.66 |    71.82 |    89.29 |    91.37 |                |
------------------------------|----------|----------|----------|----------|----------------|
```

Clearly, for some of the contracts we have to write some more tests to increase coverage.

# Estimating Gas costs

If we run the tests with the environment variable `REPORT_GAS=true`, then the output will contain information about the Gas usage of the transactions.

```sh
cd bca-token-solidity
REPORT_GAS=true npx hardhat test
```

Will output:
```sh
·----------------------------------------------|---------------------------|--------------|-----------------------------·
|             Solc version: 0.8.24             ·  Optimizer enabled: true  ·  Runs: 1000  ·  Block limit: 30000000 gas  │
···············································|···························|··············|······························
|  Methods                                                                                                              │
·························|·····················|·············|·············|··············|···············|··············
|  Contract              ·  Method             ·  Min        ·  Max        ·  Avg         ·  # calls      ·  usd (avg)  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceController  ·  newService         ·          -  ·          -  ·     1106858  ·            4  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceFunding24   ·  deposit            ·     100100  ·     156994  ·      138029  ·           12  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceInstance    ·  makeDeposit        ·      51323  ·     105528  ·      101656  ·           28  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceInstance    ·  stop               ·          -  ·          -  ·       49123  ·            4  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceInstance    ·  withdrawProvider   ·      70814  ·     105014  ·       87939  ·            9  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceInstance    ·  withdrawUser       ·          -  ·          -  ·       73013  ·            2  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceManager     ·  newController      ·    1385995  ·    1402892  ·     1394444  ·            4  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken       ·  approve            ·      46388  ·      46448  ·       46417  ·           25  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken       ·  burn               ·      33963  ·      33975  ·       33971  ·            6  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken       ·  mint               ·      36620  ·      70856  ·       61634  ·           26  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken       ·  setBurnerAddress   ·          -  ·          -  ·       56508  ·            1  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken       ·  setMinterAddress   ·          -  ·          -  ·       56486  ·            1  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken       ·  setServiceAddress  ·          -  ·          -  ·       54551  ·            2  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken       ·  transfer           ·      29706  ·      51582  ·       45948  ·           13  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  BCAServiceToken       ·  transferFrom       ·          -  ·          -  ·       57616  ·            3  ·          -  │
·························|·····················|·············|·············|··············|···············|··············
|  Deployments                                 ·                                          ·  % of limit   ·             │
···············································|·············|·············|··············|···············|··············
|  BCAServiceFunding24                         ·          -  ·          -  ·      854510  ·        2.8 %  ·          -  │
···············································|·············|·············|··············|···············|··············
|  BCAServiceInstance                          ·          -  ·          -  ·      769313  ·        2.6 %  ·          -  │
···············································|·············|·············|··············|···············|··············
|  BCAServiceManager                           ·          -  ·          -  ·     1781152  ·        5.9 %  ·          -  │
···············································|·············|·············|··············|···············|··············
|  BCAServiceToken                             ·          -  ·          -  ·     1175977  ·        3.9 %  ·          -  │
·----------------------------------------------|-------------|-------------|--------------|---------------|-------------·
```