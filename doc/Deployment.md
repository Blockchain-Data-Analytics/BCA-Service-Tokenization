# Deployment

Depending on the target chain, we run for deployment of the contracts:

## Deploy to local node

First, run a node in another terminal:
```sh
cd bca-token-solidity
npx hardhat compile
npx hardhat node
```

* if this our first run of the node, then we can import the list of output accounts into MetaMask
* in other cases it might be necessary to "clear activity" in MetaMask for these accounts so it resyncs with the node and starts with the first block

Then, deploy the ERC20 contract along with the service manager contract:

```sh
npx hardhat ignition deploy ignition/modules/BCA_Token.ts --network localhost
npx hardhat ignition deploy ignition/modules/BCA_ServiceManager.ts --network localhost
```

## Deploy to Amoy testnet

- tbd

## Deploy to Polygon mainnet

- tbd
