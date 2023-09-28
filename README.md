# Web3 Blog Creator Tables Contract

## Project Design

![image](https://github.com/ychenz/web3-blog-creator-tables-contract/assets/10768904/9e34f784-6964-463f-b02b-96c20ffc8b68)

This project work closely with the other 3 components shown in the above architecture, this smart contract is the required by all other 3 components.

- [Web3 blog creator](https://github.com/ychenz/web3-blog-creator)
- [Web3 blog creator API](https://github.com/ychenz/web3-blog-creator-api)
- [Blog template (creator created blog site)](https://github.com/ychenz/web3-fvm-blog-template)


## Local Development Setup

1. Compile the contracts, run the following

```
npm install
npm run build
```

2. Startup Local Tableland and Hardhat nodes, run the following:

```
npm run up
```

3. Deploy the contract to the hardhat node

```
npm run deploy:up
```

4. Copy the smart contract address for later use when setting up the [API](https://github.com/ychenz/web3-blog-creator-api) and the [blog template](https://github.com/ychenz/web3-fvm-blog-template).

## Deploy the contract to Filecoin Calibration Testnet

For this to work, you will need to define `FILECOIN_CALIBRATION_PRIVATE_KEY` in your `.env` file.

```
npx hardhat run scripts/deploy.ts --network filecoin-calibration
```

## Reference

This project is created from https://github.com/tablelandnetwork/hardhat-ts-tableland-template
