# Service Tokenization


## ERC20 Service Contract


![Contract interactions](./img/UC1.png)


### public methods
The ERC20 contract allows the following methods:

- totalSupply
- transfer

### administration methods
These methods can only be called from the _serviceAccount_

- setServiceAddress
- setMinterAddress
- setBurnerAddress


### supply methods

- mint
> only allowed from the _minter_

- burn
> only allowed from the _burner_

> will burn tokens in the _serviceAccount_


### transfer method

This method only allows to transfer tokens from a user's account to the _serviceAccount_

Users cannot transfer tokens to their addresses.

