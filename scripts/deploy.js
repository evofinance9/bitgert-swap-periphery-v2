const hre = require("hardhat");

async function main() {
	const [account] = await hre.ethers.getSigners();
	console.log(`Deployer account: ${account.address}`);

	// deploy token contract
	const RewardToken = await hre.ethers.getContractFactory("RewardToken");
	const rewardToken = await RewardToken.deploy("100000000000000");

	const factoryAddress = "0x4A28e53A3A4427F911526baD815FC3e1a853e86b";
	const WBRISEAddress = "0x0eb9036cbE0f052386f36170c6b07eF0a0E3f710";
	const rewardTokenAddress = rewardToken.address;

	const SwapRouter = await hre.ethers.getContractFactory("BitgertSwapRouter");
	const swapRouter = await SwapRouter.deploy(
		factoryAddress,
		WBRISEAddress,
		rewardTokenAddress
	);

	await swapRouter.deployed();

	console.log("Router deployed to: ", swapRouter.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
