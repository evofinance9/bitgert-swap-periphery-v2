require("@nomiclabs/hardhat-waffle");
require("dotenv").config();

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
	const accounts = await hre.ethers.getSigners();

	for (const account of accounts) {
		console.log(account.address);
	}
});

module.exports = {
	solidity: {
		version: "0.6.6",
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
		},
	},
	networks: {
		hardhat: {},
		testnet: {
			url: process.env.TESTNET_ADDRESS,
			accounts: { mnemonic: process.env.MNEMONIC },
		},
		mainnet: {
			url: process.env.MAINNET_ADDRESS,
			chainId: 32520,
			gasPrice: 5000000000,
			accounts: { mnemonic: process.env.MNEMONIC },
		},
	},
};
