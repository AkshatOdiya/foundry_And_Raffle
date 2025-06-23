Few of the Initials:
1. If you get the error of VRFCoordinatorV2PlusMock you can add it from VRFCoordinatorV2PlusMock folder to desired location.
2. While testing, in HelperConfig.s.sol add your sepolia testnet private key, just for testing purpose otherwise it will throw error of not having enough funds.

# Raffle
This smart contract allows for a **fully automated** Smart Contract Lottery where users can buy a lottery ticket by entering a raffle. Functions like `checkUpkeep` and `performUpkeep` will automate the lottery process, ensuring the system runs without manual intervention.

Using **Chainlink VRF** version 2.5 for randomness. The `fulfillRandomWords` function will handle the selection of the random winner and reset the lottery, ensuring a provably fair system.
