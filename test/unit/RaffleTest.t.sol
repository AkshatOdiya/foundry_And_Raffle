// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "src/Raffle.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig, constants} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2PlusMock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2PlusMock.sol";

/**
 * @dev expectEmit() cheatcode of foundry https://book.getfoundry.sh/cheatcodes/expect-emit?highlight=expectEm#expectemit
 */
contract RaffleTest is Test, constants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public immutable i_player = makeAddr("Billionaire");
    uint256 public constant STARTING_BALANCE = 1 ether;

    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    HelperConfig.NetworkConfig config;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();
        config = helperConfig.getConfig();
        vm.deal(i_player, STARTING_BALANCE);
    }

    function testRaffleState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnterRaffleRevertWhenEnoughEthIsNotPaid() public {
        //Arrange
        vm.prank(i_player);
        //Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);

        raffle.enterRaffle();
    }

    function testIfPlayerRecorded() public {
        //Arrange
        vm.prank(i_player);
        //Act
        raffle.enterRaffle{value: 0.01 ether}();
        //Assert
        assert(raffle.getNumberOfPlayers() == 1);
    }

    // Testing Events
    function testEnteringRaffleEmitsEvent() public {
        vm.prank(i_player);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(i_player);
        raffle.enterRaffle{value: 0.01 ether}();
    }

    modifier raffleEntredAndTimePassed() {
        //Arrange
        vm.prank(i_player);
        raffle.enterRaffle{value: 0.01 ether}();
        //warp function(foundry cheatcode) will set the block timestamp, to make sure enough time has passed
        vm.warp(block.timestamp + config.interval + 1);
        //roll function will change the block number
        vm.roll(block.number + 1);
        _;
    }

    // performUpkeep will set the raffle state to calculating so we will use it to do this test
    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public raffleEntredAndTimePassed {
        raffle.performUpkeep("");
        //Act/Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(i_player);
        raffle.enterRaffle{value: 0.01 ether}();
    }

    function testCheckUpkeepHaveEnoughBalance() public {
        //Arrange
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepIfRaffleIsOpen() public raffleEntredAndTimePassed {
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        //assert
        assert(upkeepNeeded == true);
    }

    //testing with parameterised custom error
    function testPerformUpkeepRevertsIfUpkeepIsNotNeeded() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                0, // balance
                0, // players
                0 // raffleState
            )
        );
        raffle.performUpkeep("");
    }

    //getting data from emitted events in our tests
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntredAndTimePassed {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[0];

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    modifier skipFork() {
        if (block.chainid != LOCAL_CHAIN_ID) {
            return;
        }
        _;
    }

    // FuzzTesting
    // This test will surely fail on fork url as we are using a mock contract,
    // and the real version of the contract is most likely different.
    // Mocks are usually simplified to facilitate ease of testing.
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntredAndTimePassed
        skipFork
    {
        // Arrange
        // Act / Assert
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2PlusMock(config.vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    //This test will fail on fork url(sepolia rpc url) as VRFCoordinatorV2PlusMock is included
    //so we can create a modifier to skip for this
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public skipFork raffleEntredAndTimePassed {
        // Arrange

        uint256 additionalEntrants = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_BALANCE);
            raffle.enterRaffle{value: config.entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Pretend to be Chainlink VRF
        VRFCoordinatorV2PlusMock(config.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = config.entranceFee * (additionalEntrants + 1);

        assert(expectedWinner == recentWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
