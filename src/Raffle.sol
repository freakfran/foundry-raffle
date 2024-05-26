// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

//import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
//import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

///// UPDATE IMPORTS TO V2.5 /////
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title 一个简单的抽奖合约示例
 * @author ge1u
 * @notice 此示例用于创建一个基于Chainlink VRFv2的抽奖合约
 * @dev 实现了Chainlink VRFv2接口
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /**
     * Errors
     */
    error Raffle__NotEnoughEthSent(); // 抽奖费用不足
    error Raffle__TransferFailed(); // 转账失败
    error Raffle__RaffleNotOpen(); // 抽奖未开放
    error Raffle__UpkeepNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

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
    uint32 private constant NUM_WORDS = 1; // 随机数字数

    uint256 private immutable i_entranceFee; // 抽奖费用
    uint256 private immutable i_interval; // 抽奖间隔
    //VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // VRF协调器
    bytes32 private immutable i_gasLane; // Gas Lane标识
    uint256 private immutable i_subscriptionId; // 订阅ID
    uint32 private immutable i_callbackGasLimit; // 回调Gas限制

    address payable[] private s_players; // 参与者列表
    address private s_recentWinner; // 最近的获胜者
    uint256 private s_lastTimeStamp; // 最后一次抽奖时间戳
    RaffleState private s_raffleState; // 抽奖状态

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
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        //i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit EnterRaffle(msg.sender);
    }

    //触发定时的条件
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        //1. 是否到间隔时间
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        //2. 合约是否在开放状态
        bool isOpen = s_raffleState == RaffleState.OPEN;
        //3. 是否有玩家
        bool hasPlayers = s_players.length > 0;
        //4. 合约内是否有余额
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasPlayers && hasBalance;
        return (upkeepNeeded, "0x0");
    }

    //执行定时任务
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING;
        // Will revert if subscription is not set and funded.
        s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_gasLane,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );
        //        i_vrfCoordinator.requestRandomWords(
        //            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        //        );
    }

    //随机数回调函数
    function fulfillRandomWords(uint256, /*_requestId*/ uint256[] calldata _randomWords) internal override {
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        emit WinnerPicked(winner);
        (bool success,) = winner.call{value: address(this).balance}("");
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /**
     * Getters
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }
}
