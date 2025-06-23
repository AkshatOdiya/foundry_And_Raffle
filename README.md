Few of the Initials:
1. If you get the error of VRFCoordinatorV2PlusMock you can add it from VRFCoordinatorV2PlusMock folder to desired location.
2. While testing, in HelperConfig.s.sol add your sepolia testnet private key, just for testing purpose otherwise it will throw error of not having enough funds.

# Raffle Using Foundry, Chainlink VRF, Chainlink Automation
This smart contract allows for a **fully automated** Smart Contract Lottery where users can buy a lottery ticket by entering a raffle. Functions like `checkUpkeep` and `performUpkeep` will automate the lottery process, ensuring the system runs without manual intervention.

Using **Chainlink VRF** version 2.5 for randomness. The `fulfillRandomWords` function will handle the selection of the random winner and reset the lottery, ensuring a provably fair system.
This document outlines the best practices and essential concepts for building a secure and efficient raffle smart contract using **Foundry**, **Chainlink VRF**, and **Chainlink Automation**.

-----

## Solidity Style Guide

Adhering to a consistent style guide improves code readability and maintainability. For Solidity contracts, the recommended layout is as follows:

```solidity
// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract

// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private

// view & pure functions
```

-----

## Custom Errors

Custom errors are more **gas-efficient** than traditional `require` statements.

```solidity
error Raffle_NotEnoughEthSent();

function enterRaffle() external payable {
    // require(msg.value >= i_entranceFee, "Not enough ETH sent!");
    if(msg.value < i_entranceFee) revert Raffle__NotEnoughEthSent();
}
```

> **[\!NOTE]** When creating custom errors, always prefix them with the **contract's name**. This helps in identifying the origin of the error, especially in large projects.

You can also pass **parameters** to custom errors to provide more detailed information about the cause of a transaction failure:

```solidity
// Example with parameters:
error Raffle__UpkeepNotNeeded(uint256 balance, uint256 length, uint256 raffleState);
```

-----

## Events

Solidity [`event`](https://docs.soliditylang.org/en/v0.8.25/contracts.html#events) are crucial for smart contracts to communicate with the outside world. They allow logging and notifying external entities, such as user interfaces or other smart contracts, about specific actions or state changes within the contract.

```solidity
event EnteredRaffle(address indexed player);

// Emitting an event:
function enterRaffle() external payable {
    if(msg.value < i_entranceFee) revert Raffle__NotEnoughEthSent();
    s_players.push(payable(msg.sender));
    emit EnteredRaffle(msg.sender);
}
```

  * For an event to be logged, it must be `emit`ted.
  * **Indexed parameters** are also known as `topics`. An event can have a maximum of three `topics`.

-----

## Chainlink VRF

**Chainlink VRF (Verifiable Random Function)** is a service that provides secure and verifiable randomness to smart contracts on blockchain platforms.

### How It Works

1.  **Requesting Randomness:** A smart contract calls the `requestRandomness` function provided by Chainlink VRF, sending a request to the Chainlink oracle along with the necessary fees.
2.  **Generating Randomness:** An off-chain Chainlink oracle node securely generates a random number and a cryptographic proof of its verifiable generation.
3.  **Returning the Result:** The oracle returns the random number and its proof to the smart contract.

### Understanding Key Functions

Consider the `VRFv2Consumer.sol` contract example ([Open in Remix](https://remix.ethereum.org/#url=https://docs.chain.link/samples/VRF/VRFv2Consumer.sol&autoCompile=true)) from the [Chainlink VRFv2 Docs](https://docs.chain.link/vrf/v2/subscription/examples/get-a-random-number#create-and-deploy-a-vrf-v2-compatible-contract).

```solidity
struct RequestStatus {
    bool fulfilled; // whether the request has been successfully fulfilled
    bool exists;    // whether a requestId exists
    uint256[] randomWords;
}

mapping(uint256 => RequestStatus) public s_requests; // requestId --> requestStatus
uint256[] public requestIds;

uint256 public lastRequestId;
```

This structure tracks VRF requests using a mapping from `requestId` to a `RequestStatus` struct. The `subscriptionId` is stored as a state variable and validated by `VRFCoordinatorV2PlusMock` to ensure a valid and sufficiently funded subscription.

The `VRFCoordinatorV2Interface` is a key dependency. The most important function is `requestRandomWords`, which initiates the random number generation process:

```solidity
// Assumes the subscription is funded sufficiently.
function requestRandomWords()
    external
    onlyOwner
    returns (uint256 requestId)
{
    // Will revert if subscription is not set and funded.
    requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
    );
    s_requests[requestId] = RequestStatus({
        randomWords: new uint256[](0),
        exists: true,
        fulfilled: false
    });
    requestIds.push(requestId);
    lastRequestId = requestId;
    emit RequestSent(requestId, numWords);
    return requestId;
}
```

This function calls `requestRandomWords` on the `VRFCoordinatorV2Interface`, which returns a `requestId`. This `requestId` is then recorded in the `s_requests` mapping, added to the `requestIds` array, and `lastRequestId` is updated.

After `requestRandomWords` is called, Chainlink will invoke your `fulfillRandomWords` function, providing the `_requestId` and the `_randomWords`. This is where your contract's logic for using the random number (e.g., drawing a raffle winner, assigning NFT traits) is implemented.

The `keyHash` (or `gasLane`) specifies the maximum gas price you're willing to pay for a request. You can find available **gas lanes** for different networks [here](https://docs.chain.link/vrf/v2/subscription/supported-networks).

### Essential Considerations for VRF Integration

1.  **Consumer Contract:** Your `Raffle` contract must inherit from a Chainlink VRF consumer base (e.g., `VRFConsumerBaseV2Plus`).
2.  **VRF Coordinator:** The VRF Coordinator must be defined as an **immutable variable** and initialized in the constructor.

When `Raffle::performUpkeep` is called, a request for a random number is sent to the VRF coordinator using `s_vrfCoordinator`. This involves passing a `VRFV2PlusClient.RandomWordsRequest` struct to `requestRandomWords`, which generates a **request ID**.

After sufficient block confirmations, the Chainlink Node will generate a random number and call the `VRFConsumerBaseV2Plus::rawFulfillRandomWords` function. This function validates the caller and then invokes the `fulfillRandomWords` function in your `Raffle` contract, where the random number is utilized.

-----

## Enum

An **enum** (enumeration) is a user-defined data type that restricts a variable to have only one of a predefined set of values. These values are represented as unsigned integers, starting from 0.

In the Raffle project, enums can prevent new entries while a winner is being picked. For example:

```solidity
// Type declarations
enum RaffleState {
    OPEN,           // 0
    CALCULATING     // 1
}

// State variable
RaffleState private s_raffleState;
```

In the constructor:

```solidity
s_raffleState = RaffleState.OPEN;
```

When picking a winner, update the state:

```solidity
function pickWinner() external {
    // check to see if enough time has passed
    if (block.timestamp - s_lastTimeStamp < i_interval) revert();

    s_raffleState = RaffleState.CALCULATING;
    // ...
}
```

Remember to revert the `s_raffleState` to `OPEN` within the `fulfillRandomWords` function once the winner has been selected.

-----

## The Checks-Effects-Interactions (CEI) Pattern

The **Checks-Effects-Interactions (CEI) pattern** is a critical security best practice in Solidity, primarily designed to prevent **reentrancy attacks**. It also contributes to gas efficiency.

The pattern involves structuring your functions in three distinct phases:

  * **Checks:** First, validate all inputs and conditions to ensure the function can execute safely. This includes checking permissions, input validity, and prerequisites related to the contract's state.
  * **Effects:** Next, modify the internal state of your contract based on the validated inputs. All internal state changes should occur before any external interactions.
  * **Interactions:** Finally, perform any external calls to other contracts or accounts. Placing external calls last is crucial to prevent reentrancy attacks, where an external call could recursively call back into the original function before it completes.

Consider the following example:

```solidity
function coolFunction() public {
    sendA();     // Interaction
    callB();     // Interaction
    checkX();    // Check
    checkY();    // Check
    updateM();   // Effect
}
```

In this problematic example, if `checkX()` fails after `sendA()` and `callB()` have executed, gas is wasted on operations that will eventually be reverted.

The CEI pattern reorganizes the function for efficiency and security:

```solidity
function coolFunction() public {
    // Checks
    checkX();
    checkY();

    // Effects
    updateStateM();

    // Interactions
    sendA();
    callB();
}
```

By performing checks first, you minimize gas costs on failed transactions. Effects are then applied internally, and finally, external interactions are made, ensuring that the contract's state is fully updated and secure before any external calls could potentially trigger a reentrancy.

-----

## Chainlink Automation

**Chainlink Automation** is a decentralized service that automates smart contract functions and DevOps tasks reliably, trust-minimized, and cost-efficiently. It enables smart contracts to execute transactions automatically based on predefined conditions or schedules.

  * You can find more detailed documentation on Chainlink Automation [here](https://docs.chain.link/chainlink-automation/guides/compatible-contracts) and [here](https://docs.chain.link/chainlink-automation/guides/job-scheduler).
  * For a tutorial on using the Chainlink UI for Automation, refer to this [Updraft tutorial](https://updraft.cyfrin.io/courses/foundry/smart-contract-lottery/chainlink-automation?lesson_format=transcript).

-----

## Testing the Smart Contract

When testing smart contracts, the **AAA (Arrange-Act-Assert)** pattern is highly recommended.

There are two primary approaches to deciding where to begin testing:

1.  **Easy to Complex:** Start with simple **view functions**, then progress to smaller, internal functions, and finally tackle more complex functions.
2.  **Main Entry Point to Periphery:** Begin by testing the primary entry points that external users interact with, then move to the underlying functionalities. For example, in a Raffle contract, the `enterRaffle` function would be a key starting point.

### New Foundry Cheatcodes

Foundry provides powerful cheatcodes for testing:

1.  [`expectEmit()`](https://www.google.com/search?q=%5Bhttps://book.getfoundry.sh/cheatcodes/expect-emit%3Fhighlight%3DexpectEm%23expectemit%5D\(https://book.getfoundry.sh/cheatcodes/expect-emit%3Fhighlight%3DexpectEm%23expectemit\)): Used for testing events.
2.  [`vm.warp`](https://www.google.com/search?q=%5Bhttps://book.getfoundry.sh/cheatcodes/warp%3Fhighlight%3Dwarp%23warp%5D\(https://book.getfoundry.sh/cheatcodes/warp%3Fhighlight%3Dwarp%23warp\)): Sets the `block.timestamp` for testing time-dependent logic.
3.  [`vm.roll`](https://www.google.com/search?q=%5Bhttps://book.getfoundry.sh/cheatcodes/roll%3Fhighlight%3Droll%23roll%5D\(https://book.getfoundry.sh/cheatcodes/roll%3Fhighlight%3Droll%23roll\)): Sets the `block.number`.
4.  [`skip`](https://www.google.com/search?q=%5Bhttps://book.getfoundry.sh/reference/forge-std/skip%5D\(https://book.getfoundry.sh/reference/forge-std/skip\)): Advances the `block.timestamp` by a specified number of seconds.
5.  [`rewind`](https://www.google.com/search?q=%5Bhttps://book.getfoundry.sh/reference/forge-std/rewind%5D\(https://book.getfoundry.sh/reference/forge-std/rewind\)): Rewinds the `block.timestamp` by a specified number of seconds.

### Code Coverage Report

To identify which lines of code are covered by your tests, generate a detailed coverage report.

Use the following command to create a `coverage.txt` file, which lists the uncovered lines of code:

```bash
forge coverage --report debug > coverage.txt
```

-----

## Fuzz Testing

**Fuzz testing**, or fuzzing, is an automated software testing technique that involves injecting invalid, malformed, or unexpected inputs into a system. Its goal is to uncover software defects and vulnerabilities that might lead to crashes, security breaches, or performance issues. Fuzzing works by feeding a program large volumes of random data ("fuzz") and observing how the system responds. Abnormal behavior or crashes indicate potential vulnerabilities.

For example, in Foundry, you can specify input parameters in test functions, and Foundry will provide random values for those parameters during fuzzing:

```solidity
function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
    public
    raffleEntredAndTimePassed
{
    // Arrange
    // Act / Assert
    vm.expectRevert(VRFCoordinatorV2PlusMock.InvalidRequest.selector);
    // vm.mockCall could be used here...
    VRFCoordinatorV2PlusMock(vrfCoordinator).fulfillRandomWords(
        randomRequestId,
        address(raffle)
    );
}
```

This allows you to test your contract's robustness against a wide range of unexpected inputs.
