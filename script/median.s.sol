// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console2} from "forge-std/Script.sol";
import {Median} from "../src/median.sol";

contract MedianScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console2.logString("Deploying median implementation");
        Median median = new Median(1, address(1234), address(5678));
        string memory logMessage = string.concat("Median contract address: ", vm.toString(address(median)));
        console2.logString(logMessage);

        // for testing with local relayer client
        median.authorizeNode(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

        vm.stopBroadcast();
    }
}
