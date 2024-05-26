// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint256) {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,,,,) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256) {
        console.log("Creating subscription on chainId: ", block.chainid);
        vm.startBroadcast();
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Subscription ID: ", subscriptionId);
        console.log("Please update HelperConfig.s.sol with the new subscription ID");
        return subscriptionId;
    }

    function run() external returns (uint256) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,, uint256 subscriptionId,, address link) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subscriptionId, link);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address link) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On chainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address consumerContract) public {
        HelperConfig helperConfig = new HelperConfig();
        (,, address vrfCoordinator,, uint256 subscriptionId,,) = helperConfig.activeNetworkConfig();
        addConsumer(consumerContract, vrfCoordinator, subscriptionId);
    }

    function addConsumer(address consumerContract, address vrfCoordinator, uint256 subscriptionId) public {
        console.log("Adding consumer contract: ", consumerContract);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On chain id: ", block.chainid);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, consumerContract);
        vm.stopBroadcast();
    }

    function run() external {
        address raffleAddress = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(raffleAddress);
    }
}
