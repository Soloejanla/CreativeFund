# CreativeFund

A decentralized crowdfunding platform for creative projects built on the Stacks blockchain.

## Overview

CreativeFund enables creators to raise funds for their creative projects by tokenizing them on the Stacks blockchain. Backers can purchase tokens to support projects they believe in and receive rewards proportional to their contribution when the project generates revenue.

## Features

- **Project Creation**: Creators can register their projects with details, funding goals, and token pricing
- **Project Backing**: Supporters can back projects by purchasing tokens
- **Reward Distribution**: Creators can distribute rewards to token holders
- **Transparent Fees**: Platform charges a small fee (default 2%) on reward distributions

## Contract Functions

### For Creators

- `create-project`: Register a new creative project
- `add-rewards`: Add rewards to be distributed to project backers
- `distribute-rewards`: Initiate the distribution of rewards to backers

### For Backers

- `back-project`: Support a project by purchasing tokens
- `claim-rewards`: Claim your share of project rewards

### For Platform Administrators

- `set-platform-fee`: Update the platform fee percentage (contract owner only)

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) for local development and testing
- [Stacks Wallet](https://www.hiro.so/wallet) for interacting with the deployed contract

### Development

1. Clone this repository
2. Run `clarinet check` to verify the contract
3. Run `clarinet test` to execute the test suite

## License

This project is licensed under the MIT License - see the LICENSE file for details.
\`\`\`
