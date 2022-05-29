const hre = require("hardhat");

async function main() {
  const [account] = await hre.ethers.getSigners();
  console.log(`Deployer account: ${account.address}`);

  const factoryAddress = "0x02650a330F980362e7B233CF80b96D0Db04293b2";
  const WBRISEAddress = "0x0eb9036cbE0f052386f36170c6b07eF0a0E3f710";

  const SwapRouter = await hre.ethers.getContractFactory("BitgertSwapRouter");
  const swapRouter = await SwapRouter.deploy(factoryAddress, WBRISEAddress);

  await swapRouter.deployed();

  console.log("Router deployed to: ", swapRouter.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
