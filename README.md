# Bitgert Swap Periphery


# Local Development

The following assumes the use of `node@>=10`.

## Install Dependencies

`yarn`

## Add Environment Variables

`MNEMONIC="YOUR_WALLET_MNEMONIC"`\
`TESTNET_ADDRESS="https://testnet-rpc.brisescan.com"`\
`MAINNET_ADDRESS="https://chainrpc.com"`

## Compile Contracts

`npx hardhat compile`

## Deploy Contract

> :warning: **Deployment Warning**: Before deployment update **factoryAddress** variable in `scripts/deploy.js` and **INIT_CODE_HASH** in `contracts/libraries/BitgertSwapLibrary.sol`!

`npx hardhat run scripts/deploy.js --network mainnet`