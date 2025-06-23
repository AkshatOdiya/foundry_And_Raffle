// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2PlusMock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2PlusMock.sol";
/**
 * @dev This mock link token Contract from Patrick uses dependency ERC20 Contract
 * It can be installed using  `forge install transmissions11/solmate`
 */
import {LinkToken} from "test/mocks/LinkToken.sol";

/**
 * @title HelperConfig
 * @dev This contract is used to store the configuration for different networks.
 * It includes the entrance fee, interval, VRF coordinator address, gas lane, subscription ID,
 * and callback gas limit for each network.
 * @author Akshat Odiya
 * See: https://docs.chain.link/vrf/v2-5/supported-networks for VRF coordinator addresses.
 * See: https://docs.chain.link/vrf/v2-5/supported-networks for gas lane(here, 500 gwei key hash)
 * See: https://docs.chain.link/resources/link-token-contracts?parent=vrf for link token contract
 */
abstract contract constants {
    /* Mock parameters */
    uint96 public MOCK_BASE_FEE = 0.001 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    int256 public MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111; // Chain ID for Sepolia
    uint256 public constant LOCAL_CHAIN_ID = 31337; // Chain ID for local development
}

contract HelperConfig is Script, constants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    uint256 public constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfig;

    constructor() {
        networkConfig[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        // ChainIB of ETH sepolia is 1115511, you can see on Chainlist by typing ethereum sepolia
        // Verifying that a VRF coordinator exists
        if (networkConfig[chainId].vrfCoordinator != address(0)) {
            return networkConfig[chainId];
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        //we need to use memory keyword because this is a NetworkConfig is a special object

        NetworkConfig memory sepoliaConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30 seconds,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // Sepolia VRF Coordinator
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // Sepolia gas lane
            subscriptionId: 0, //put your subscriptionId, that you got from chainlink while create subscrip tion
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployerKey: 0x794 // put you sepolia private key here
        });

        return sepoliaConfig;
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }
        vm.startBroadcast();
        VRFCoordinatorV2PlusMock vrfCoordinatorMock = new VRFCoordinatorV2PlusMock(
                MOCK_BASE_FEE,
                MOCK_GAS_PRICE_LINK
            );
        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether, //1e16
            interval: 30 seconds,
            vrfCoordinator: address(vrfCoordinatorMock), // Mock VRF Coordinator
            //gasLane doesnt matter, Mock will work anyway
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // Sepolia gas lane
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken),
            deployerKey: DEFAULT_ANVIL_KEY // Any default anvil private key
        });
        return localNetworkConfig;
    }
}
