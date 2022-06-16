const hre = require("hardhat");

async function main() {
	const [account] = await hre.ethers.getSigners();
	console.log(`Deployer account: ${account.address}`);

	// deploy token contract
	const factoryAddress = "0x4e5855A85eD76B246d1F3620741AC95d421A73A2";
	const WBRISEAddress = "0x0eb9036cbE0f052386f36170c6b07eF0a0E3f710";
	const rewardTokenAddress = "0x6ab7616635425a1045712e119B9f2c8923c09f23";

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
