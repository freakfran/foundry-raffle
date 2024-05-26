// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
    }

    uint256 public constant SEPOLIA_CHAIN_ID = 11155111;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            console.log("Using Sepolia ETH");
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            console.log("Using Ganache ETH");
            activeNetworkConfig = getOrCreateGanacheEthConfig();
        }
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) {
        //https://docs.chain.link/vrf/v2-5/supported-networks
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 10404536840554839472755995080569833297743141827685573786500750992623312062789,
            callbackGasLimit: 500000,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateGanacheEthConfig() public returns (NetworkConfig memory) {
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }
        uint96 baseFee = 0.002 ether;
        uint96 gasPrice = 40 gwei; //1e9 gwei link
        int256 weiPerUnitLink = 0.004 ether;
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(baseFee, gasPrice, weiPerUnitLink);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorV2_5Mock),
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: 500000,
            link: address(linkToken)
        });
    }
}
