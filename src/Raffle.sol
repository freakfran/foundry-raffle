// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

/**
 * @title 一个简单的抽奖合约示例
 * @author ge1u
 * @notice 此示例用于创建一个基于Chainlink VRFv2的抽奖合约
 * @dev 实现了Chainlink VRFv2接口
 */
contract Raffle is VRFConsumerBaseV2 {
    /**
     * Errors
     */
    error Raffle__NotEnoughEthSent(); // 抽奖费用不足
    error Raffle__TransferFailed(); // 转账失败
    error Raffle__RaffleNotOpen(); // 抽奖未开放

    /**
     * Type Declarations
     */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /**
     * State Variables
     */
    uint16 private constant REQUEST_CONFIRMATIONS = 3; // 请求确认数
    uint32 private constant NUM_WORDS = 1;           // 随机数字数

    uint256 private immutable i_entranceFee;      // 抽奖费用
    uint256 private immutable i_interval;          // 抽奖间隔
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // VRF协调器
    bytes32 private immutable i_gasLane;             // Gas Lane标识
    uint64 private immutable i_subscriptionId;       // 订阅ID
    uint32 private immutable i_callbackGasLimit;     // 回调Gas限制

    address payable[] private s_players; // 参与者列表
    address private s_recentWinner;       // 最近的获胜者
    uint256 private s_lastTimeStamp;     // 最后一次抽奖时间戳
    RaffleState private s_raffleState;    // 抽奖状态

    /**
     * Events
     */
    event EnterRaffle(address indexed player);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value >= i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnterRaffle(msg.sender);
    }

    //1. Get a random number
    //2. Pick a winner with the random number
    //3. Be automatically called
    function pickWinner() external {
        if (block.timestamp - s_lastTimeStamp <= i_interval) {
            revert();
        }
        s_raffleState = RaffleState.CALCULATING;
        // Will revert if subscription is not set and funded.
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );
    }

    function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal override {
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        (bool success,) = winner.call{value: address(this).balance}("");
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        if (!success){
            revert Raffle__TransferFailed();
        }
        emit WinnerPicked(winner);
    }

    /**
     * Getters
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
