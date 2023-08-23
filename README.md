# Reward Pool distribution Smart Contract

This is [BonusBlock](https://www.bonusblock.io) reward pool distribution smart contract for EVM based networks

Deployment using hardhat for Ethereum Sepolia testnet

```shell
npx hardhat run scripts/deploy.ts --network sepolia
```

Contract verification

```shell
npx hardhat verify --network sepolia <contractAddress> <claimFeeNative> <poolCreationFeePercentage>
```
