// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {HelperConfig, constants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2PlusMock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2PlusMock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
// DevOpsTools can be downloaded from: `forge install Cyfrin/foundry-devops`
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 * @dev you can read https://docs.chain.link/vrf/v2-5/subscription/create-manage#create-a-subscription-programmatically to know how *they* implement subscription and add consumer
 */

/**
 * @dev We need to insert the private key too to broadcast when we are *fork* testing
 * because we want dont want an error, as vm.startBroadcast will randomly assign an private key/account and test will through error
 * Therefore we need to update HelperConfig too, addding an 'deployerKey' parameter.
 */
contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 deployerKey = helperConfig.getConfig().deployerKey;
        (uint256 subId,) = createSubscription(vrfCoordinator, deployerKey);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint256, address) {
        console2.log("creating subscription on chain Id: ", block.chainid);
        vm.startBroadcast(deployerKey);
        /*
        when you want to interact with a contract at a specific address, you cast the address to the contract type using the syntax ContractType(address).
        This cast expects exactly one argument: the address of the deployed contract.
        */
        uint256 subId = VRFCoordinatorV2PlusMock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console2.log("Your SubId is: ", subId);
        //you should add this subId to your HelperConfig.s.sol
        return (subId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, constants {
    uint256 public constant FUND_AMOUNT = 3 ether; //3 Link
    address linkToken;

    // In order to fund the subscription, we need
    // 1. VrfCoordintor address
    // 2. SubscriptionId
    // 3. Link Tokens

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;
        linkToken = helperConfig.getConfig().link;
        uint256 deployerKey = helperConfig.getConfig().deployerKey;

        fundSubscription(vrfCoordinator, subscriptionId, linkToken, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address, /*linkToken */
        uint256 deployerKey
    ) public {
        console2.log("Funding Subscription: ", subscriptionId);
        console2.log("Using VrfCoordinator: ", vrfCoordinator);
        console2.log("On ChainId: ", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast(deployerKey);
            /**
             * @dev here, we need that `vrfCoordinator` to be a contract, specifically the `VRFCoordinatorV2PlusMock` contract that we've imported.
             * We are casting the `vrfCoordinator` address as `VRFCoordinatorV2PlusMock` to be able to call it inside the function.
             * @dev "The address stored in vrfCoordinator points to a deployed instance of the VRFCoordinatorV2PlusMock contract, and by typecasting it,
             * we are directly calling the fundSubscription() function of that deployed contract.
             * When using Anvil (a local chain), there is no real LINK token — it’s just mock testing.
             * So instead, we do this:
             */
            VRFCoordinatorV2PlusMock(vrfCoordinator).fundSubscription(subscriptionId, uint96(FUND_AMOUNT));
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            /**
             * @dev The `transferAndCall` function is part of the `ERC-677 standard`, which extends the `ERC-20` token standard by adding the ability to execute a function call in the recipient contract immediately after transferring tokens.
             * This feature is particularly useful in scenarios where you want to atomically transfer tokens and trigger logic in the receiving contract within a single transaction, enhancing efficiency and reducing the risk of reentrancy attacks.
             * In the context of Chainlink, the LINK token implements the `transferAndCall` function.
             * When a smart contract wants to request data from a Chainlink oracle, it uses this function to send LINK tokens to the oracle's contract address while simultaneously encoding the request details in the \_data parameter.
             * The oracle's contract then decodes this data to understand what service is being requested.
             * We are calling transferAndCall of the LINK token contract.
             * With this statement we are telling vrfCoordinator,"These LINK tokens are for this specific subscription ID."
             * The VRFCoordinator receives the LINK tokens and credits your subscription with them.
             * This is the official way to fund a subscription to chainlink vrf service while creating subscription
             */
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

/*
Consumers are contracts that can request randomness from Chainlink VRF.
To enable a contract to request randomness, 
you must first add its address as an approved consumer of your subscription
*/
contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subId = helperConfig.getConfig().subscriptionId;
        uint256 deployerKey = helperConfig.getConfig().deployerKey;

        addConsumer(mostRecentlyDeployed, vrfCoordinator, subId, deployerKey);
    }

    /**
     * @dev We need to establish the fact that our `Raffle` contract is a consumer of Chainlink VRF
     */
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, uint256 deployerKey)
        public
    {
        console2.log("Adding consumer contract: ", contractToAddToVrf);
        console2.log("To VrfCoordinator: ", vrfCoordinator);
        console2.log("On ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2PlusMock(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
