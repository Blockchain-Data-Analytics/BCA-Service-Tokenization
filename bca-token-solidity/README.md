# BCA Token

## setup

`npm install`

`npx hardhat init`

# Run the tests

```sh
npx hardhat compile
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat coverage
```

### local test deployment
in one terminal start a node:
```sh
npx hardhat node
```
in the other deploy the contracts
```sh
npx hardhat ignition deploy ignition/modules/BCA_Token.ts --network localhost
npx hardhat ignition deploy ignition/modules/BCA_ServiceManager.ts --network localhost
```

#### Connect metamask to local node

RPC: http://127.0.0.1:8545/
Chain id: 31337

The node has output a list of accounts it created. These can be imported into Metamask using the private keys: create new account, import with private key.


### start web gui

```sh
cd ../bca-token-app
cp ../bca-token-solidity/ignition/deployments/chain-31337/artifacts/BCA_Token\#BCAServiceToken.json ./src/lib/bca_token-abi.json
npm run dev
```
(the second command copies the ABI from the compiled and deployed contract so we know how to call functions in the contract)

- copy the contract's address from: `../bca-token-solidity/ignition/deployments/chain-31337/deployed_addresses.json`
- set the contract's address in the source files: `const contractAddress = ..`

open the app on http://localhost:5173

note: import the token into Metamask using the contract's address so the token balance will show up

- the first account is the current owner of the contract
- set the minter and burner to the second, third addresses
- mint some tokens (using the minter account) for the fourth address (user1)
- transfer some tokens from user1 to user2 - should not work
- transfer some tokens from user1 to the service account - should work
- burn some tokens from the service account



### GAS estimation
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
