// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/utils/cryptography/MessageHashUtils.sol";
import {Median} from "../src/median.sol";
import {Proxy} from "../src/proxy.sol";

contract MedianTest is Test {
    using MessageHashUtils for bytes;
    using ECDSA for bytes32;

    Median median;
    Proxy proxy;

    uint256 relayer1PrivKey = uint256(keccak256("relayer 1"));
    uint256 relayer2PrivKey = uint256(keccak256("relayer 2"));
    uint256 ownerPrivKey = uint256(keccak256("owner"));
    address relayer1 = vm.addr(relayer1PrivKey);
    address relayer2 = vm.addr(relayer2PrivKey);
    address owner = vm.addr(ownerPrivKey);

    // -- ERRORS --
    error NotEnoughPrices();
    error OnlyAuthorizedRelayers();
    error InvalidArrayLength();
    error InvalidSignature();
    error InvalidTimestamp();
    error OwnableUnauthorizedAccount(address account);
    error ECDSAInvalidSignature();
    error PricesNotOrdered();
    error InvalidQuorum();

    function preSetup() private {
        vm.warp(vm.unixTime() / 100);

        vm.label(relayer1, "relayer 1");
        vm.label(relayer2, "relayer 2");
        vm.label(owner, "owner");
        vm.label(address(proxy), "default proxy");
        vm.label(address(median), "default median");
    }

    function setUp() public {
        preSetup();

        vm.startPrank(owner);

        // deploy
        median = new Median();
        bytes memory initializeData = abi.encodeCall(Median.initialize, (1));
        proxy = new Proxy(address(median), initializeData);

        // set authorized relayers
        Median preparedProxy = castIntoMedianType(proxy);

        preparedProxy.authorizeRelayer(relayer1);
        preparedProxy.authorizeRelayer(relayer2);

        vm.stopPrank();
    }

    function castIntoMedianType(Proxy _proxy) private pure returns (Median) {
        return Median(address(_proxy));
    }

    function updateParameters(Median preparedProxy, uint256 privKey)
        private
        view
        returns (uint256[] memory _prices, uint64[] memory _timestamps, bytes[] memory _signatures)
    {
        _prices = new uint256[](1);
        _timestamps = new uint64[](1);
        _signatures = new bytes[](1);
        uint8[] memory _v = new uint8[](1);
        bytes32[] memory _r = new bytes32[](1);
        bytes32[] memory _s = new bytes32[](1);

        _prices[0] = 1e6;
        _timestamps[0] = uint64(block.timestamp);

        bytes32 messageDigest =
            abi.encode(_prices[0], _timestamps[0], preparedProxy.currencyPair()).toEthSignedMessageHash();
        (_v[0], _r[0], _s[0]) = vm.sign(privKey, messageDigest);

        _signatures[0] = abi.encodePacked(_r[0], _s[0], _v[0]);
    }

    function test_update_basic() external {
        Median preparedProxy = castIntoMedianType(proxy);

        (uint256[] memory _prices, uint64[] memory _timestamps, bytes[] memory _signatures) =
            updateParameters(preparedProxy, relayer1PrivKey);

        vm.startPrank(relayer1);
        preparedProxy.update(_prices, _timestamps, _signatures);

        (uint256 lastTimestamp, uint256 lastPrice) = preparedProxy.read();
        assertEq(lastTimestamp, block.timestamp);
        assertEq(lastPrice, 1e6);

        (uint128 timestamp, uint128 price) = preparedProxy.priceHistory(0);
        assertEq(timestamp, block.timestamp);
        assertEq(price, 1e6);
    }

    function test_update_reverts_if_not_authorized_signer() external {
        Median preparedProxy = castIntoMedianType(proxy);

        (uint256[] memory _prices, uint64[] memory _timestamps, bytes[] memory _signatures) =
            updateParameters(preparedProxy, relayer1PrivKey);

        vm.expectRevert(OnlyAuthorizedRelayers.selector);
        preparedProxy.update(_prices, _timestamps, _signatures);
    }

    function test_update_reverts_if_not_minimum_price_source_quorum() external {
        Median preparedProxy = castIntoMedianType(proxy);

        (uint256[] memory _prices, uint64[] memory _timestamps, bytes[] memory _signatures) =
            updateParameters(preparedProxy, relayer1PrivKey);

        // increase quorum
        vm.prank(owner);
        preparedProxy.updateMinimumQuorum(2);

        vm.startPrank(relayer1);
        vm.expectRevert(NotEnoughPrices.selector);
        preparedProxy.update(_prices, _timestamps, _signatures);
    }

    function test_update_reverts_if_invalid_signature_or_wrong_signer() external {
        Median preparedProxy = castIntoMedianType(proxy);

        (uint256[] memory _prices, uint64[] memory _timestamps, bytes[] memory _signatures) =
            updateParameters(preparedProxy, ownerPrivKey);

        vm.startPrank(relayer1);

        // test with sigs that recover to a diff address that's not relayer1
        vm.expectRevert(InvalidSignature.selector);
        preparedProxy.update(_prices, _timestamps, _signatures);

        // test with sigs that recover to address(0)
        assembly {
            let lenOffsetOfSignatureAtIndex0 := mload(add(_signatures, 0x20))
            // write 17 to the _v value of the sig at index 0
            // 0x61 derived from := 0x20 (len space) + 0x40 (r and v space)
            mstore8(add(lenOffsetOfSignatureAtIndex0, 0x60), 17) // any non zero value will do apart from 27 and 28
        }
        vm.expectRevert(ECDSAInvalidSignature.selector);
        preparedProxy.update(_prices, _timestamps, _signatures);
    }

    function test_update_reverts_if_prices_not_ordered() external {
        Median preparedProxy = castIntoMedianType(proxy);

        uint256[] memory _prices = new uint256[](2);
        uint64[] memory _timestamps = new uint64[](2);
        bytes[] memory _signatures = new bytes[](2);

        _prices[0] = 1e6;
        _timestamps[0] = uint64(block.timestamp);

        bytes32 messageDigest =
            abi.encode(_prices[0], _timestamps[0], preparedProxy.currencyPair()).toEthSignedMessageHash();
        (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(relayer1PrivKey, messageDigest);

        _signatures[0] = abi.encodePacked(_r, _s, _v);

        _prices[1] = 0.99999e6;
        _timestamps[1] = uint64(block.timestamp);

        messageDigest = abi.encode(_prices[1], _timestamps[1], preparedProxy.currencyPair()).toEthSignedMessageHash();
        (_v, _r, _s) = vm.sign(relayer1PrivKey, messageDigest);

        _signatures[1] = abi.encodePacked(_r, _s, _v);

        vm.startPrank(relayer1);

        // test with sigs that recover to a diff address that's not relayer1
        vm.expectRevert(PricesNotOrdered.selector);
        preparedProxy.update(_prices, _timestamps, _signatures);
    }

    function test_authorize_relayer() external {
        Median preparedProxy = castIntoMedianType(proxy);
        assertEq(preparedProxy.authorizedRelayersCount(), 2);

        // if called by non owner, should revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, (address(this))));
        preparedProxy.authorizeRelayer(address(1234567890));

        // call by owner should not revert
        vm.prank(owner);
        preparedProxy.authorizeRelayer(address(1234567890));

        // assertions
        assertTrue(preparedProxy.authorizedRelayers(address(1234567890)));
        assertEq(preparedProxy.authorizedRelayersCount(), 3);
    }

    function test_deauthorize_relayer() external {
        Median preparedProxy = castIntoMedianType(proxy);
        assertEq(preparedProxy.authorizedRelayersCount(), 2);

        // authorize relayer
        vm.prank(owner);
        preparedProxy.deauthorizeRelayer(address(1234567890));

        // if called by non owner, should revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, (address(this))));
        preparedProxy.deauthorizeRelayer(address(1234567890));

        // call by owner should not revert
        vm.prank(owner);
        preparedProxy.deauthorizeRelayer(address(1234567890));

        // assertions
        assertFalse(preparedProxy.authorizedRelayers(address(1234567890)));
        assertEq(preparedProxy.authorizedRelayersCount(), 2);
    }

    function test_update_minimum_quorum() external {
        Median preparedProxy = castIntoMedianType(proxy);
        assertEq(preparedProxy.minimumQuorum(), 1);

        // if called by non owner, should revert
        vm.expectRevert(abi.encodeWithSelector(OwnableUnauthorizedAccount.selector, (address(this))));
        preparedProxy.updateMinimumQuorum(2);

        // call by owner should not revert
        vm.prank(owner);
        preparedProxy.updateMinimumQuorum(2);

        // assertions
        assertEq(preparedProxy.minimumQuorum(), 2);
    }

    function test_update_minimum_quorum_reverts_if_set_to_0() external {
        Median preparedProxy = castIntoMedianType(proxy);
        assertEq(preparedProxy.minimumQuorum(), 1);

        // call by owner should not revert
        vm.prank(owner);
        vm.expectRevert(InvalidQuorum.selector);
        preparedProxy.updateMinimumQuorum(0);
    }
}
