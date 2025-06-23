// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";

// When we deploy our contract, we also need to create create a subscription and add consumer
contract DeployRaffle is Script, HelperConfig {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        //when the subscriptId is 0, we can create a subscription and add a consumer
        if (config.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator, config.deployerKey);

            //Fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator, config.subscriptionId, config.link, config.deployerKey
            );
        }
        /**
         * @dev We need to insert the private key too to broadcast when we are *fork* testing
         * because we want dont want an error, as vm.startBroadcast will randomly assign an private key/account and test will through error
         * Therefore we need to update HelperConfig too, addding an 'deployerKey' parameter
         */
        vm.startBroadcast(config.deployerKey);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        //We dont need broadcast here because it is there in addConsumer function in Interactions.s.sol
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.deployerKey);
        return (raffle, helperConfig);
    }
}
