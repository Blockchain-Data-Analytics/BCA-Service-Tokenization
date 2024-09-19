
# BCA Service Token

## Version: 2024-09-18
## Copyright: 2024 Alexander Diemand
## License: GPLv3 - GNU GENERAL PUBLIC LICENSE Version 3


### Overview

This is an evaluation of how we could use tokens on a blockchain to charge users for their usage of our services.
Such a setup would give us great flexibility in creating new services and have revenue streams from micro-payments.
Users benefit from keeping control of the budget of their service usage and only expose a minimal stake at any time.
Charging for services is done transparently on-chain.
The user with a positive token balance has access to an agent that helps funding service usage: by time, using fixed budget, ...
Our services can be compared to mice which need some cheese from time to time to make them happy.
We might call that Geez (GEZ), similar to Ethereum's GAS.


### Principles & Ideas

- users have to aquire our token for feeding our services with Geez
- we mint new tokens to the user on payment in fiat. Later: they might also pay in crypto to some smart contract.
- users own that tokens and can see them in their wallets
- before using a service, users have to transfer a small amount of tokens to our address
- the user's tokens are burnt and a Geez record of it is kept in our database linked to the sender. Proof is the on-chain transaction.
- services are then enabled for that user; they will deduct Geez from time to time in the db; (this part could be solved in our own L2 network, one day)
- users can see their Geez balance and transactions in a dashboard
- users can optionally add monitoring to their Geez budget: as soon as it drops below a certain level, then an email is sent to them asking for refunding


### First attempt

a first attempt has been run on Polygon's Amoy testnet. 

see [Amoy_test.md](Amoy_test.md)


## Solidity contract and testing

see [README](./bca-token-solidity/README.md) in directory [./bca-token-solidity](./bca-token-solidity/)


## Frontend for minting/burning of tokens

see [README](./bca-token-app/README.md) in directory [./bca-token-app](./bca-token-app/)

