import { ethers } from "hardhat";

async function main() {
  const claimFeeNative = 1000;
  const poolCreationFeePercentage = 10;

  const rewardPoolFactory = await ethers.getContractFactory("RewardPool");

  const rewardPool = await rewardPoolFactory.deploy(claimFeeNative, poolCreationFeePercentage);

  await rewardPool.waitForDeployment();

  console.log(
    `RewardPool with claim fee ${claimFeeNative} and creation fee ${poolCreationFeePercentage}% deployed to ${rewardPool.target}`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});