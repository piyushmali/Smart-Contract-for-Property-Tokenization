# Real Estate Tokenization Platform

This project is a Solidity-based smart contract system for tokenizing real estate properties with KYC (Know Your Customer) restrictions. It consists of three main contracts: `KYCRegistry` for managing investor verification, `RestrictedRealEstateToken` for representing fractional property ownership, and `RestrictedPropertyTokenFactory` for creating new tokenized properties with multisig governance. The system ensures that only KYC-verified investors can transfer tokens, enhancing regulatory compliance.

Deployed on the **Sepolia testnet**, this implementation showcases a decentralized approach to real estate investment.

## Contracts Overview

### 1. KYCRegistry
- **Purpose**: Manages a registry of KYC-verified investors using a role-based access control system.
- **Key Features**:
  - Role-based permissions: `ADMIN_ROLE` and `VERIFIER_ROLE`.
  - Functions to verify, revoke, and batch-verify investors.
  - Event logging for transparency.
- **Address**: `0x4712a11dF1927311F5A1822170306B36941171f1`

### 2. RestrictedRealEstateToken
- **Purpose**: An ERC20 token representing fractional ownership of a real estate property, with transfer restrictions based on KYC status.
- **Key Features**:
  - Property metadata (ID, location, valuation, etc.).
  - KYC checks on all transfers.
  - Owner controls for updating valuation, legal documents, and burning tokens.
  - Token value calculation based on property valuation.
- **Address**: `0xad84B15AFC1a5A2D7c236DCC1dD91A084dC57c3F`

### 3. RestrictedPropertyTokenFactory
- **Purpose**: A factory contract to deploy new `RestrictedRealEstateToken` instances, with multisig governance for KYC operations.
- **Key Features**:
  - Deploys tokenized properties with unique IDs.
  - Multisig KYC verification process (propose, sign, execute).
  - Tracks all tokenized properties.
  - Admin management for multisig operations.
- **Address**: `0x6bD4afec19Eb57603e18Bf8F9A49f07644529b3A`

## Deployment Details

- **Network**: Sepolia Testnet
- **Deployed Addresses**:
  - **KYCRegistry**: `0x4712a11dF1927311F5A1822170306B36941171f1`
  - **RestrictedPropertyTokenFactory**: `0x6bD4afec19Eb57603e18Bf8F9A49f07644529b3A`
  - **RestrictedRealEstateToken**: `0xad84B15AFC1a5A2D7c236DCC1dD91A084dC57c3F`
- **Compiler Version**: Solidity `^0.8.20`
- **Dependencies**: OpenZeppelin Contracts (`ERC20`, `Ownable`, `AccessControl`, `Strings`)

These contracts were deployed on **February 26, 2025**, and are publicly accessible for testing on Sepolia. Ensure you have Sepolia ETH to interact with them (available via faucets like [Sepolia Faucet](https://sepoliafaucet.com/)).

## Features

- **KYC Compliance**: Only KYC-verified addresses can transfer `RestrictedRealEstateToken` tokens, enforced by the `KYCRegistry`.
- **Property Tokenization**: Each `RestrictedRealEstateToken` represents a unique real estate asset with on-chain metadata.
- **Multisig Governance**: KYC operations in the factory require multiple admin signatures, enhancing security.
- **Flexibility**: Property owners can update valuation and legal document hashes, while the factory supports creating multiple properties.
- **Transparency**: Events emitted for all key actions (e.g., token creation, KYC verification, transfers).

## Prerequisites

- **Wallet**: MetaMask or any Ethereum-compatible wallet configured for Sepolia.
- **Sepolia ETH**: For gas fees (get from a Sepolia faucet).
- **Tooling**: Remix, Hardhat, or Truffle for interacting with the contracts (optional: use Etherscan’s contract interface).
- **Etherscan**: Verify and interact with contracts at [Sepolia Etherscan](https://sepolia.etherscan.io/).

## Usage Instructions

### 1. Setup
- Connect your wallet to the Sepolia testnet.
- Add the contract addresses to your interface (e.g., Remix or Etherscan).

### 2. Interacting with RestrictedPropertyTokenFactory
- **Deploy New Property Token**:
  - **Function**: `createPropertyToken`
  - **Example Inputs**:
    - `_propertyId`: `"PROP002"`
    - `_location`: `"456 Oak Ave, Los Angeles, CA"`
    - `_totalValuation`: `150000000000000000000` (150 ETH in wei)
    - `_propertyType`: `"Commercial"`
    - `_legalDocumentHash`: `"QmY...efgh"`
    - `_tokenName`: `"Oak Avenue Token"`
    - `_tokenSymbol`: `"OAT"`
    - `_totalSupply`: `2000000000000000000000` (2000 tokens)
  - **Caller**: Factory owner (initially deployer).
  - **Result**: Deploys a new token contract.

- **Propose KYC Verification**:
  - **Function**: `proposeVerifyInvestor`
  - **Example Input**: `0xYourAddress...`
  - **Caller**: Multisig admin.
  - **Result**: Creates an operation ID (e.g., `1`).

- **Sign Operation**:
  - **Function**: `signOperation`
  - **Example Input**: `1` (operation ID)
  - **Caller**: Another multisig admin.
  - **Result**: Executes if signature threshold (e.g., 2) is met.

### 3. Interacting with KYCRegistry
- **Check Verification Status**:
  - **Function**: `isVerified`
  - **Example Input**: `0xYourAddress...`
  - **Result**: Returns `true` or `false`.

- **Note**: Direct interaction is typically via the factory’s multisig, but verifiers can use `verifyInvestor` if granted the role.

### 4. Interacting with RestrictedRealEstateToken
- **Get Property Info**:
  - **Function**: `getPropertyInfo`
  - **Result**: Returns property details as a string.

- **Transfer Tokens**:
  - **Function**: `transfer`
  - **Example Inputs**:
    - `to`: `0xRecipientAddress...` (must be KYC-verified)
    - `value`: `10000000000000000000` (10 tokens)
  - **Caller**: Token holder (must be KYC-verified).
  - **Result**: Transfers tokens if KYC checks pass.

- **Update Valuation**:
  - **Function**: `updateValuation`
  - **Example Input**: `160000000000000000000` (160 ETH in wei)
  - **Caller**: Token owner.

## Example Workflow
1. **Deployer** (e.g., `0xDeployer...`) owns the factory at `0x6bD4afec19Eb57603e18Bf8F9A49f07644529b3A`.
2. **Create Token**: Deploy a new property token (e.g., "PROP001" at `0xad84B15AFC1a5A2D7c236DCC1dD91A084dC57c3F`).
3. **KYC Verification**:
   - Admin 1 proposes `proposeVerifyInvestor(0xInvestor...)`.
   - Admin 2 signs with `signOperation(operationId)`.
   - Investor is verified in `0x4712a11dF1927311F5A1822170306B36941171f1`.
4. **Transfer**: Deployer transfers 10 tokens to the verified investor.

## ABI and Source Code
- **Source Code**: Available in this repository or verified on [Sepolia Etherscan](https://sepolia.etherscan.io/).
- **ABI**: Extract from Etherscan or compile the contracts using Solidity `^0.8.20`.

## Security Considerations
- **Centralization**: Token owners have significant control (e.g., burning, updates). Consider multisig ownership for production.
- **Multisig**: Ensure enough admins are active to meet the signature threshold.
- **KYC Dependency**: Transfers fail if the `KYCRegistry` is unavailable or misconfigured.
- **Gas Costs**: Batch operations and multisig signing may be expensive with many participants.

## Future Enhancements
- Add emergency stop functionality for token transfers.
- Implement a frontend interface for easier interaction.
- Extend multisig to token creation and ownership changes.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact
For questions or support, reach out via GitHub Issues or contact the deployer (details TBD).
