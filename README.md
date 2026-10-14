
# BCA Market for Tokenized Services

[![Aiken contracts](https://github.com/Blockchain-Data-Analytics/BCA-Service-Tokenization/actions/workflows/aiken.yaml/badge.svg)](https://github.com/Blockchain-Data-Analytics/BCA-Service-Tokenization/actions/workflows/aiken.yaml)
[![TypeScript packages](https://github.com/Blockchain-Data-Analytics/BCA-Service-Tokenization/actions/workflows/typescript.yaml/badge.svg)](https://github.com/Blockchain-Data-Analytics/BCA-Service-Tokenization/actions/workflows/typescript.yaml)
[![Solidity tests](https://github.com/Blockchain-Data-Analytics/BCA-Service-Tokenization/actions/workflows/sol_testing.yaml/badge.svg)](https://github.com/Blockchain-Data-Analytics/BCA-Service-Tokenization/actions/workflows/sol_testing.yaml)
[![Slither](https://github.com/Blockchain-Data-Analytics/BCA-Service-Tokenization/actions/workflows/analysis_slither.yaml/badge.svg)](https://github.com/Blockchain-Data-Analytics/BCA-Service-Tokenization/actions/workflows/analysis_slither.yaml)

#### Version: 2026-10-05
#### Copyright: 2024-2026 Alexander Diemand
#### [License](./LICENSE): GPLv3 - GNU GENERAL PUBLIC LICENSE Version 3

## Continuous integration

The same checks run on GitHub (`.github/workflows`) and Forgejo (`.forgejo/workflows`);
both call `ci/aiken.sh` and `ci/typescript.sh`, so they can also be run locally.

They run inside the CI image built from `docker/Dockerfile.ci-cardano`. Each platform
publishes it to its own registry, named by the Actions variable `CI_IMAGE` (image name
without tag), and tags it with `docker/ci-cardano.version` (plus `latest`):

| platform | `CI_IMAGE` | image built by |
|---|---|---|
| GitHub | `ghcr.io/blockchain-data-analytics/ci-cardano` | `build-ci-cardano-image.yaml`, on demand from the CI workflows |
| Forgejo | `code.blockchain-applied.com/bca/ci-cardano` | `build-ci-cardano-image.yaml` (on `main` or manually) |

The TypeScript job also needs a secret with a Forgejo token (`read:package`) for the
`@bca` npm registry: `BCA_NPM_TOKEN` on GitHub, `PAT` on Forgejo.

## Documentation

[see documentation](./doc/README.md)

## Overview

We are developing the tokenization of services and have them managed on a blockchain with smart contracts.

The contracts' behaviour is defined by a fixed set of parameters.

Our product creates a market for tokenized services and brings users and service providers together.

![Overview](./doc/img/service_contract.png)

New and in progress: the same contract also runs on the Cardano network

## Principles & Ideas

- micropayments in a stable-coin (EUR, USD)
- alternative: ERC20 token pegged to a currency, on/off-ramp from/to fiat
- users keep their funds in their wallets, and only commit a small amount in deposits to the service contract
- optionally, users can subscribe to a bot that deposits every 24 hours the required funds to keep services running
- at any time either the user or the provider can call stop() and the contract halts
- at any time both the user and the provider can withdraw funds from the service contract: up to the calculated balance at the current block time
- the contracts store the necessary information and thus no party relies on a centralized backend for operations

## Micropayments and balance calculation

The service contract is created with a set of parameters which are fixed for the lifetime of the contract.

The calculation of the user's and provider's balances depend on the contracts start time and the current time, taken from the latest block.

Once the user makes her first deposit, the contract starts. Multiple deposits can be made by the user. And, both parties can withdraw up to their calculated balance.

![User and provider balance in the contract](./doc/img/service_micropayment.png)

## Solidity contracts and testing

see [README](./bca-token-solidity/README.md) in directory [./bca-token-solidity](./bca-token-solidity/)

## Frontend to interact with service contracts

Both users and providers connect to this user interface to interact with the service contracts.

see [README](./bca-token-market/README.md) in directory [./bca-token-market](./bca-token-market/)


## Frontend for minting/burning of tokens

Developping and testing is done using our own ERC20 token that mimics a stable-coin.

see [README](./bca-token-app/README.md) in directory [./bca-token-app](./bca-token-app/)
