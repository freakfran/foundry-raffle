// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    event EnterRaffle(address indexed player);

    Raffle private raffle;
    HelperConfig private helperConfig;
    uint256 private entranceFee;
    uint256 private interval;
    address private vrfCoordinator;
    bytes32 private gasLane;
    uint256 private subscriptionId;
    uint32 private callbackGasLimit;
    address private link;

    address private PLAYER = makeAddr("player");
    uint256 private constant START_PLAYER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (entranceFee, interval, vrfCoordinator, gasLane, subscriptionId, callbackGasLimit, link) =
            helperConfig.activeNetworkConfig();
        vm.deal(PLAYER, START_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /**
     * Enter raffle
     */
    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        address rafflePlayer = raffle.getPlayer(0);
        assert(rafflePlayer == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.startPrank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnterRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
    }

    function testCantEnterWhenRaffleIsCalculating() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /**
     * checkUpkeep
     */
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(upkeepNeeded);
    }

    /**
     * performUpkeep
     */
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.startPrank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEnteredAndTimePassed {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        //RequestRaffleWinner是触发的第二个事件，所以用entries[1]
        //topics[0]代表整个事件
        bytes32 requestId = entries[1].topics[1];
        assert(uint256(requestId) > 0);

        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(rState) == 1);
    }
}
