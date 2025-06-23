// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
// These dependencies can be installed using
// forge install smartcontractkit/chainlink-brownie-contracts@1.3.0
// and do remappings to foundry.toml

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample lottery Contract
 * @author Akshat Odiya
 * @notice Simulating a sample raffle
 * @dev Implements Chainlink VRFv2.5
 */

/**
 * @dev When we call the `Raffle::performUpkeep` function, we send a request for a **random number** to the VRF coordinator, using the `s_vrfCoordinator` variable inherited from `VRFConsumerBaseV2Plus`.
 * This request involves passing a `VRFV2PlusClient.RandomWordsRequest` struct to the `requestRandomWords` method, which generates a **request ID**.
 *
 * After a certain number of block confirmations, the Chainlink Node will generate a random number and call the `VRFConsumerBaseV2Plus::rawFulfillRandomWords` function.
 * This function validates the caller address and then invokes the `fulfillRandomWords` function in our `Raffle` contract.
 *
 * @notice Since `VRFConsumerBaseV2Plus::fulfillRandomWords` is marked as `virtual`, we need to **override** it in its child contract.
 *  This requires defining the actions to take when the random number is returned, such as selecting a winner and distributing the prize
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /*Custom Errors */
    error Raffle__MoreEthRequireToEnterRaffle();
    error Raffle__TransferFail();
    error Raffle__RaffleNotOpen();

    // We can also know the reason for this error by setting parameters
    error Raffle__upkeepNotNeeded(uint256 balance, uint256 numberOfPlayer, uint256 raffleState);

    /* Type Declaration (using Enum) */
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    /**
     * @dev REQUEST_CONFIRMATION: specifies the number of block confirmations required before the Chainlink VRF node responds to a randomness request
     * more the number, more the security, more the time taken by process
     * 3 blocks for Chainlink VRF to send us the random number this means that we have at least 36 seconds (12 seconds/block) of time when our Raffle is processing the winner.
     * callbackGasLimit: needs to be adjusted depending on the number of random words you request and the logic you are employing in the callback function.
     */

    /* State Variables */
    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_interval;
    uint32 private immutable i_callbackGasLimit;
    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    // We made the array payable because the one who wins will be given the amount
    address payable[] private s_players;
    /**
     * @dev to set the interval for lottery(after how much time the pickWinner will be called to get the winner of raffle)
     */
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 requestId);

    /**
     * @dev if you inherit the contract that have a contructor then you need to add that contract's constructor
     */
    constructor(
        uint256 entraceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entraceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    // Function to enter to lottery, who wants to enter
    // To enter a user has to pay a entrace fee, that why it is 'payable'
    function enterRaffle() public payable {
        // require(msg.value>=i_entraceFee,"Not Enough ETH to enter to Raffle!");
        // Storing these kinds of string is not GAS efficient, instead we will do -->

        // require(msg.value>=i_entraceFee,MoreEthRequireToEnterRaffle());

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        // Another update(More GAS Efficient) -->
        if (msg.value < i_entranceFee) {
            revert Raffle__MoreEthRequireToEnterRaffle();
        }
        // We nned to store the participants too, and the winner need to be paid, therefore it is `payable`
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev We need to automate this, pick the winner automatially after decided interval
     * We can do this by Chainlink Automation
     * This is the function(checkUpkeep) that the chainlink keeper nodes call
     * @return upkeepNeeded - Chainlink keeper nodes will look upkeepNeeded to be true.
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayer = s_players.length > 0;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        upkeepNeeded = timeHasPassed && hasBalance && hasPlayer && isOpen;
        return (upkeepNeeded, "");
        // We don't use the checkData in this example. The checkData is defined when the Upkeep was registered.
    }

    // function to pick a winner of the lottery
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__upkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState) //Typecasting
            );
        }
        s_raffleState = RaffleState.CALCULATING;
        // Get our random number
        // Getting a random on blockchain is hard, because it is a determininstic system
        // Therefore we're going to use Chainlink VRF

        // To get random numbers, it is a two transaction process
        // 1. Request Random Number Generation(RNG) to Oracle
        // 2. Get the RNG from Oracle network
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        ); // This is how we are calling Chainlink VRF to get a random number

        // This emitting is redudant and ww want to save gas usage
        // Inside the `VRFCoordinatorV2PlusMock` you'll find that the `requestRandomWords` emits a giant event called `RandomWordsRequested` that contains the `requestId` we are also emitting in our new event.
        emit RequestedRaffleWinner(requestId);
    }

    /**
     * @dev  This function(fuldillRandomWords) is necessarily required to be implemented here
     * when you inherit a abstract contract that has a function marked 'virtual'
     * and you do not 'override' this in child contract, the compiler will ask you to make child contract 'abstract'
     * fulfillRandomWords will be called by the `vrfCoordinator` when it sends back the requested `randomWords`.
     * This is also where we'll select our winner.
     */

    // CEI: Checks, Effects, Interactions Pattern
    // After calling chainlink VRF (see above), Chainlink will respond to this fulfillRandomWords and....

    function fulfillRandomWords(uint256, /*requestId*/ uint256[] calldata randomWords) internal override {
        //That randomWord will be a long uint256, so we need to scale it, as shown
        //Calculated indexOfWinner ranges from 0 to s_player.length-1;
        uint256 indexOfWinner = randomWords[0] % s_players.length;

        //we need to pay the winner
        address payable recentWinner = s_players[indexOfWinner];

        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;

        // After the raffle state is open, we need to clean the list for new entrants
        s_players = new address payable[](0);

        // Additionally, we are starting up a fresh raffle, we also need to bring the `s_lastTimeStamp` to the present time.
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(s_recentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFail();
        }
    }

    function getEntraceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayersLength() external view returns (uint256) {
        return s_players.length;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
