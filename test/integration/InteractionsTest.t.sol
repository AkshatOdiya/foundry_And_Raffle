// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/Script.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";

import {VRFCoordinatorV2PlusMock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2PlusMock.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract InteractionsTest is Test, HelperConfig {
    Raffle public raffle;
    DeployRaffle public deployRaffle;
    HelperConfig public helperConfig;
    address tester = makeAddr("Billionaire");
    HelperConfig.NetworkConfig config;
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        vm.deal(tester, STARTING_USER_BALANCE);
    }

    function testcreateSubscriptionUsingConfigParamtersAreSetCorrectly() public {
        vm.prank(tester);

        VRFCoordinatorV2PlusMock vrfCoordinatorMock = new VRFCoordinatorV2PlusMock(MOCK_BASE_FEE, MOCK_GAS_PRICE_LINK);

        CreateSubscription createSubscription = new CreateSubscription();
        (uint256 subId, address vrfCoordinator) = createSubscription.createSubscriptionUsingConfig();
        // subId is preknow
        assert(subId > 0);
        // This will work as instances are different
        assert(vrfCoordinator != address(vrfCoordinatorMock));
    }
}
