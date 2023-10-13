// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script, console2} from "forge-std/Script.sol";
import {Median} from "../src/median.sol";
import {Proxy} from "../src/proxy.sol";

contract MedianScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        console2.logString("Deploying median implementation");
        Median median = new Median();
        string memory logMessage = string.concat("Median implementation address: ", vm.toString(address(median)));
        console2.logString(logMessage);

        bytes memory initializeData = abi.encodeCall(Median.initialize, (1)); // minimumQuorum = 1

        console2.logString("Deploying proxy and pointing it to implementation");
        Proxy proxy = new Proxy(address(median), initializeData);
        logMessage = string.concat("Proxy address: ", vm.toString(address(proxy)));
        console2.logString(logMessage);

        // for testing with local relayer client
        // Median(address(proxy)).authorizeRelayer(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

        vm.stopBroadcast();
    }
}
