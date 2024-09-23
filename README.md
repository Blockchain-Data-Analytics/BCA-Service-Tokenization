
# BCA Service Token

## Version: 2024-09-18
## Copyright: 2024 Alexander Diemand
## License: GPLv3 - GNU GENERAL PUBLIC LICENSE Version 3

### Documentation

[see documentation](./doc/README.md)


### Overview

This project is an evaluation of how to use ERC20 tokens on a blockchain to charge users for their usage of our services in micro-payments without incurring massive transaction fees.
Such a setup shows large flexibility in creating new services and shows great potential for revenue streams from micro-payments.
Users benefit from keeping control over their budget of service usage costs and only expose a minimal stake at any time.
Charging for services is done transparently on-chain.
The user with a positive token balance has access to an agent that helps funding service usage: by time, using fixed budget, ...

#### Why call the internal token GEEZ?
Our services can be compared to mice which need some cheese from time to time to make them happy.
We might call that GEEZ (GEZ), similar to Ethereum's GAS.


### Principles & Ideas

- there is an on-chain service token (probably named "BCA") and an internal token (named "GEEZ") for micropayments
- users aquire the service token using a fiat on-ramp service
- we mint new tokens to the user on payment in fiat. Later: they might also pay in crypto to some smart contract
- users own the service tokens and can see them in their wallets
- before using a service, users transfer a small amount of service tokens to the service's address
- A GEEZ record of the user's tokens is kept in our database linked to the sender. Proof is the on-chain transaction
- service usage by the user will be deducte from the user's GEEZ account
  - (this part could be solved in our own L2 network, one day)
- users can see their GEEZ balance and transactions in a dashboard
- users can optionally add monitoring to their GEEZ budget: as soon as it drops below a certain level, then an email is sent to them asking for refunding


## Solidity contract and testing

see [README](./bca-token-solidity/README.md) in directory [./bca-token-solidity](./bca-token-solidity/)


## Frontend for minting/burning of tokens

see [README](./bca-token-app/README.md) in directory [./bca-token-app](./bca-token-app/)

