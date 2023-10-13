// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

//  ==========  External imports    ==========
import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ECDSA} from "@openzeppelin-contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts/utils/cryptography/MessageHashUtils.sol";

import {IMedian} from "./interfaces/IMedian.sol";

contract Median is IMedian, Initializable, OwnableUpgradeable, UUPSUpgradeable {
    using MessageHashUtils for bytes;
    using ECDSA for bytes32;

    bytes32 public constant currencyPair = 0x555344432f784e474e0000000000000000000000000000000000000000000000; // hex("USDC/xNGN);
    uint32 public minimumQuorum;
    uint64 internal lastTimestamp;
    uint128 internal lastPrice;

    mapping(address => bool) public authorizedRelayers;
    uint32 public authorizedRelayersCount;

    PriceData[] public priceHistory;

    function initialize(uint32 _minimumQuorum) public initializer {
        __Ownable_init_unchained(msg.sender);

        minimumQuorum = _minimumQuorum;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier onlyAuthorizedRelayer() {
        if (!authorizedRelayers[msg.sender]) {
            revert OnlyAuthorizedRelayers();
        }
        _;
    }

    modifier hasMinimumQuorum(uint256 pricesLength) {
        if (pricesLength < minimumQuorum) {
            revert NotEnoughPrices();
        }
        _;
    }

    function authorizeRelayer(address _relayerAddress) external onlyOwner {
        if (!authorizedRelayers[_relayerAddress]) {
            authorizedRelayers[_relayerAddress] = true;
            authorizedRelayersCount++;
        }

        emit AuthorizedRelayer(_relayerAddress);
    }

    function deauthorizeRelayer(address _relayerAddress) external onlyOwner {
        if (authorizedRelayers[_relayerAddress]) {
            authorizedRelayers[_relayerAddress] = false;
            authorizedRelayersCount--;
        }

        emit DeauthorizedRelayer(_relayerAddress);
    }

    function updateMinimumQuorum(uint32 _minimumQuorum) external onlyOwner {
        minimumQuorum = _minimumQuorum;

        emit MinimumQuorumUpdated(_minimumQuorum);
    }

    function read() external view returns (uint256, uint256) {
        return (lastTimestamp, lastPrice);
    }

    function update(
        uint256[] calldata _prices,
        uint64[] calldata _timestamps,
        uint8[] calldata _v,
        bytes32[] calldata _r,
        bytes32[] calldata _s
    ) external onlyAuthorizedRelayer hasMinimumQuorum(_prices.length) {
        if (
            _prices.length != _timestamps.length || _prices.length != _v.length || _prices.length != _r.length
                || _prices.length != _s.length
        ) {
            revert InvalidArrayLength();
        }

        // cache timestamp on the stack to save gas
        uint256 _lastTimestamp = lastTimestamp;

        for (uint256 i; i < _prices.length; ++i) {
            if (_timestamps[i] <= _lastTimestamp) {
                revert InvalidTimestamp();
            }

            address signer = recover(_prices[i], _timestamps[i], currencyPair, _v[i], _r[i], _s[i]);

            // ecdsa lib already reverts with error `ECDSAInvalidSignature()` if signer == address(0)
            if (signer != msg.sender) {
                revert InvalidSignature();
            }
        }

        uint256[] memory sortedPrices = sort(_prices);

        lastPrice = uint128(median(sortedPrices));
        lastTimestamp = _timestamps[_timestamps.length - 1];

        priceHistory.push(PriceData({timestamp: lastTimestamp, price: lastPrice}));

        emit PriceUpdated(lastTimestamp, lastPrice);
    }

    function recover(uint256 _price, uint64 _timestamp, bytes32 _pair, uint8 _v, bytes32 _r, bytes32 _s)
        internal
        pure
        returns (address)
    {
        bytes32 messageHash = abi.encodePacked(_price, _timestamp, _pair).toEthSignedMessageHash();
        return messageHash.recover(_v, _r, _s);
    }

    // Function to calculate the median of an array of values
    function median(uint256[] memory values) internal pure returns (uint256) {
        if (values.length == 0) {
            revert InvalidArrayLength();
        }

        if (values.length % 2 == 0) {
            uint256 middle1 = values[(values.length / 2) - 1];
            uint256 middle2 = values[values.length / 2];
            return (middle1 + middle2) / 2;
        } else {
            return values[values.length / 2];
        }
    }

    // Function to sort an array of values
    function sort(uint256[] memory data) internal pure returns (uint256[] memory) {
        uint256 n = data.length;
        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = i + 1; j < n; j++) {
                if (data[i] > data[j]) {
                    uint256 temp = data[i];
                    data[i] = data[j];
                    data[j] = temp;
                }
            }
        }
        return data;
    }
}