# Flow of transactions

A service instance is represented by a smart contract on a blockchain. The contract's state changes with transactions on it by the user and the service provider.

* at first, the contract is created by the service manager with references to the provider's and the user's addresses so to allow only interaction from these accounts
* the user deposits a small amount to start the contract
* both the user and the provider can intermittently withdraw funds from the contract
* the user may deposit more funds to extend the duration of the contract
* either the user or the provider call "stop" on the contract, or the contract runs out of funds
* after this point, the contract cannot be started again, the balances don't change anymore


## On-ramp, off-ramp

All services on this platform are payable in a token, named BCA1, that represents the value of one Euro per token.
Such tokens can be purchased using fiat money in our on-ramp service. And, token holders can request a payout to a bank account by returning the tokens.

### The user buys service tokens using fiat and gets credited

The user buys in a conventional fiat transaction some tokens. This is reflected by minting new tokens to the user's on-chain account.

![Fiat on-ramp](./img/tx0-1.png)


### The user deposits tokens for service micro-payments

Using an on-chain transaction, the user transfers a number of tokens to a smart contract representing a service instance.

![User deposit](./img/tx2.png)


### Balances of both parties are managed in the smart contract

After the contract is started, the user's and the provider's balances are maintained. These balances determine how much each party can withdraw from the contract. While the user's balance diminishes with time, the provider's balance will increase.

![Service usage debit](./img/tx3.png)
