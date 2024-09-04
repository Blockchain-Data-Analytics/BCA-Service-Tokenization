
# Evaluation of token deployment on Polygon's testnet Amoy


### Useful links

* Creating accounts in Metamask: https://metamask.io/
* Search for chains and connection parameters: https://chainlist.org/
* Token SOL template from https://www.openzeppelin.com/solidity-contracts
* Testnet faucet: https://faucet.polygon.technology/
* Building the contract in https://remix.ethereum.org/
    * deployed via Metamask to Amoy testnet


### Contract

based on templates from openzeppelin.

documentation: https://docs.openzeppelin.com/contracts/5.x/access-control

adaptations:

- the creator of the contract is the ServiceAccount
- minting is only possible through another account: the minter address
- burning is only possible through another account: the burner address
- transfer methods have been overridden to not allow transfer to other accounts than the ServiceAccount
    - this disallows user to user token transfers

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BCAServiceToken is ERC20, AccessControl {
    address public serviceAddress;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @dev Constructor that sets up roles and gives the deployer the default admin role.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param minter The address that will be granted the minter role.
     * @param burner The address that will be granted the burner role.
     */
    constructor(string memory name, string memory symbol, address minter, address burner)
        ERC20(name, symbol)
    {
        serviceAddress = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(BURNER_ROLE, burner);
    }

    /**
     * @dev Allows the admin to set the service address.
     * @param new_serviceAddress The address to set as the service address.
     */
    function setServiceAddress(address new_serviceAddress) public onlyRole(DEFAULT_ADMIN_ROLE) {
        serviceAddress = new_serviceAddress;
    }

    /**
     * @dev Mints new tokens. Can only be called by addresses with the MINTER_ROLE.
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens. Can only be called by addresses with the BURNER_ROLE.
     * @param from The address from which to burn tokens.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) public onlyRole(BURNER_ROLE) {
        _burn(from, amount);
    }

    /**
     * @dev Overrides the transfer function to only allow transfers to the service address.
     * @param recipient The address to transfer tokens to (must be the service address).
     * @param amount The amount of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        require(recipient == serviceAddress, "Transfer only allowed to service address");
        return super.transfer(recipient, amount);
    }

    /**
     * @dev Overrides the transferFrom function to only allow transfers to the service address.
     * @param sender The address to transfer tokens from.
     * @param recipient The address to transfer tokens to (must be the service address).
     * @param amount The amount of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        require(recipient == serviceAddress, "Transfer only allowed to service address");
        return super.transferFrom(sender, recipient, amount);
    }
}
```

### Testing

#### preparations

* create five accounts: ServiceAccount, Minter, Burner, User1, User2
* fund these accounts from the faucet: https://faucet.polygon.technology/
* deploy contract (as ServiceAccount) indicate Minter, Burner addresses in constructor

#### test cases

Testing should pass for the following test cases:

- [ ] ServiceAccount owns the contract
- [ ] ServiceAccount cannot mint
- [ ] ServiceAccount cannot burn
- [ ] Minter can mint to User1|User2
- [ ] Minter can't burn
- [ ] Burner can't mint
- [ ] User1 or User2 cannot transfer tokens to other user
- [ ] User1 and User2 can transfer to ServiceAccount
- [ ] Burner can burn from ServiceAccount (or User1|User2)

#### test log

deployed contract: https://www.oklink.com/amoy/tx/0x716bb3e2ea0965f0a38ea7509d909e36b15282b6b7c248717e214bcc6ab9d6a4

or in polygonscan: https://amoy.polygonscan.com/address/0x8575aecd20dcd1aa3fc83a0ac29b1f71714f47f3



### User interface

installation of Elixir et al. for Phoenix: https://hexdocs.pm/phoenix/installation.html

created a new app: `mix phx.new amoy_app`

```sh
We are almost there! The following steps are missing:

    $ cd amoy_app
    $ mix deps.get

Then configure your database in config/dev.exs and run:

    $ mix ecto.create

Start your Phoenix app with:

    $ mix phx.server

You can also run your app inside IEx (Interactive Elixir) as:

    $ iex -S mix phx.server
```

