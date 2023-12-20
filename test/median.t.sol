// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/utils/cryptography/MessageHashUtils.sol";
import {Median} from "../src/median.sol";

contract MedianTest is Test {
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    Median median;

    uint256 node1PrivKey = uint256(keccak256("node 1"));
    uint256 node2PrivKey = uint256(keccak256("node 2"));
    uint256 ownerPrivKey = uint256(keccak256("owner"));
    address node1 = vm.addr(node1PrivKey);
    address node2 = vm.addr(node2PrivKey);
    address owner = vm.addr(ownerPrivKey);

    // -- ERRORS --
    error NotEnoughPrices();
    error InvalidArrayLength();
    error UnauthorizedNode();
    error InvalidTimestamp();
    error OwnableUnauthorizedAccount(address account);
    error InvalidSignature();
    error AlreadySigned();
    error PricesNotOrdered();
    error InvalidQuorum();

    function preSetup() private {
        vm.warp(vm.unixTime() / 100);

        vm.label(node1, "node 1");
        vm.label(node2, "node 2");
        vm.label(owner, "owner");
        vm.label(address(median), "default median");
    }

    function setUp() public {
        preSetup();

        vm.startPrank(owner);

        // deploy
        median = new Median(1, address(1234), address(5678));

        // set authorized nodes
        median.authorizeNode(node1);
        median.authorizeNode(node2);

        vm.stopPrank();
    }

    function updateParameters(Median _median, uint256 privKey)
        private
        view
        returns (uint256[] memory _prices, uint256[] memory _timestamps, bytes[] memory _signatures)
    {
        _prices = new uint256[](1);
        _timestamps = new uint256[](1);
        _signatures = new bytes[](1);
        uint8[] memory _v = new uint8[](1);
        bytes32[] memory _r = new bytes32[](1);
        bytes32[] memory _s = new bytes32[](1);

        _prices[0] = 1e6;
        _timestamps[0] = block.timestamp;

        bytes32 messageDigest =
            keccak256(abi.encode(_prices[0], _timestamps[0], _median.currencyPair())).toEthSignedMessageHash();
        (_v[0], _r[0], _s[0]) = vm.sign(privKey, messageDigest);

        _signatures[0] = abi.encodePacked(_r[0], _s[0], _v[0]);
    }

    function test_update_basic() external {
        (uint256[] memory _prices, uint256[] memory _timestamps, bytes[] memory _signatures) =
            updateParameters(median, node1PrivKey);

        median.update(_prices, _timestamps, _signatures);

        (uint256 lastTimestamp, uint256 lastPrice) = median.read();
        assertEq(lastTimestamp, block.timestamp);
        assertEq(lastPrice, 1e6);

        (uint256 timestamp, uint256 price) = median.priceHistory(0);
        assertEq(timestamp, block.timestamp);
        assertEq(price, 1e6);
    }

    function test_update_reverts_if_not_minimum_price_source_quorum() external {
        (uint256[] memory _prices, uint256[] memory _timestamps, bytes[] memory _signatures) =
            updateParameters(median, node1PrivKey);

        // increase quorum
        vm.prank(owner);
        median.updateMinimumQuorum(2);

        vm.expectRevert(NotEnoughPrices.selector);
        median.update(_prices, _timestamps, _signatures);
    }

    function test_update_reverts_if_invalid_signature_or_wrong_signer() external {
        (uint256[] memory _prices, uint256[] memory _timestamps, bytes[] memory _signatures) =
            updateParameters(median, ownerPrivKey);

        // test with sigs that recover to a diff address that's not relayer1
        vm.expectRevert(UnauthorizedNode.selector);
        median.update(_prices, _timestamps, _signatures);

        // test with sigs that recover to address(0)
        assembly {
            let lenOffsetOfSignatureAtIndex0 := mload(add(_signatures, 0x20))
            // write 17 to the _v value of the sig at index 0
            // 0x61 derived from := 0x20 (len space) + 0x40 (r and v space)
            mstore8(add(lenOffsetOfSignatureAtIndex0, 0x60), 17) // any non zero value will do apart from 27 and 28
        }
        vm.expectRevert(InvalidSignature.selector);
        median.update(_prices, _timestamps, _signatures);
    }

    function test_update_reverts_if_prices_not_ordered() external {
        uint256[] memory _prices = new uint256[](2);
        uint256[] memory _timestamps = new uint256[](2);
        bytes[] memory _signatures = new bytes[](2);

        _prices[0] = 1e6;
        _timestamps[0] = block.timestamp;

        bytes32 messageDigest =
            keccak256(abi.encode(_prices[0], _timestamps[0], median.currencyPair())).toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(node1PrivKey, messageDigest);

        _signatures[0] = abi.encodePacked(_r, _s, _v);

        _prices[1] = 0.99999e6;
        _timestamps[1] = block.timestamp;

        messageDigest =
            keccak256(abi.encode(_prices[1], _timestamps[1], median.currencyPair())).toEthSignedMessageHash();
        (_v, _r, _s) = vm.sign(node1PrivKey, messageDigest);

        _signatures[1] = abi.encodePacked(_r, _s, _v);

        vm.expectRevert(PricesNotOrdered.selector);
        median.update(_prices, _timestamps, _signatures);
    }

    function test_authorize_node() external {
        assertEq(median.authorizedNodesCount(), 2);

        // if called by non owner, should revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, (address(this))));
        median.authorizeNode(address(1234567890));

        // call by owner should not revert
        vm.prank(owner);
        median.authorizeNode(address(1234567890));

        // assertions
        assertTrue(median.authorizedNodes(address(1234567890)));
        assertEq(median.authorizedNodesCount(), 3);
    }

    function test_deauthorize_node() external {
        assertEq(median.authorizedNodesCount(), 2);

        // authorize relayer
        vm.prank(owner);
        median.authorizeNode(address(1234567890));

        // if called by non owner, should revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, (address(this))));
        median.deauthorizeNode(address(1234567890));

        // call by owner should not revert
        vm.prank(owner);
        median.deauthorizeNode(address(1234567890));

        // assertions
        assertFalse(median.authorizedNodes(address(1234567890)));
        assertEq(median.authorizedNodesCount(), 2);
    }

    function test_update_minimum_quorum() external {
        assertEq(median.minimumQuorum(), 1);

        // if called by non owner, should revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, (address(this))));
        median.updateMinimumQuorum(2);

        // call by owner should not revert
        vm.prank(owner);
        median.updateMinimumQuorum(2);

        // assertions
        assertEq(median.minimumQuorum(), 2);
    }

    function test_update_minimum_quorum_reverts_if_set_to_0() external {
        assertEq(median.minimumQuorum(), 1);

        // call by owner should not revert
        vm.prank(owner);
        vm.expectRevert(InvalidQuorum.selector);
        median.updateMinimumQuorum(0);
    }
}
