// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

//  ==========  External imports    ==========
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {IMedian} from "./interfaces/IMedian.sol";

contract Median is IMedian, Ownable {
    bytes32 public immutable currencyPair;

    uint256 public minimumQuorum;
    uint256 private lastTimestamp;
    uint256 private lastPrice;

    uint256 public authorizedNodesCount;
    mapping(address => bool) public authorizedNodes;
    mapping(uint8 => address) public slot;

    constructor(uint256 _minimumQuorum, address currency, address collateral) Ownable(msg.sender) {
        currencyPair = keccak256(abi.encode(currency, collateral));
        minimumQuorum = _minimumQuorum;
    }

    modifier hasMinimumQuorum(uint256 pricesLength) {
        if (pricesLength < minimumQuorum) revert NotEnoughPrices();
        _;
    }

    function authorizeNode(address _nodeAddress) external onlyOwner {
        if (_nodeAddress == address(0)) revert AddressZero();
        if (authorizedNodes[_nodeAddress]) revert AlreadyAuthorized();
        uint8 mostSignificantByte = uint8(_addressToUint256(_nodeAddress) >> 152);
        if (slot[mostSignificantByte] != address(0)) revert NodeSlotTaken();

        authorizedNodes[_nodeAddress] = true;
        slot[mostSignificantByte] = _nodeAddress;
        unchecked {
            ++authorizedNodesCount;
        }

        emit AuthorizedNode(_nodeAddress);
    }

    function deauthorizeNode(address _nodeAddress) external onlyOwner {
        if (!authorizedNodes[_nodeAddress]) revert AlreadyDeauthorized();

        authorizedNodes[_nodeAddress] = false;
        uint8 mostSignificantByte = uint8(_addressToUint256(_nodeAddress) >> 152);
        slot[mostSignificantByte] = address(0);
        unchecked {
            --authorizedNodesCount;
        }

        emit DeauthorizedNode(_nodeAddress);
    }

    function updateMinimumQuorum(uint256 _minimumQuorum) external onlyOwner {
        if (_minimumQuorum == 0) revert InvalidQuorum();
        minimumQuorum = _minimumQuorum;

        emit MinimumQuorumUpdated(_minimumQuorum);
    }

    function read() external view returns (uint256, uint256) {
        return (lastTimestamp, lastPrice);
    }

    function update(uint256[] calldata _prices, uint256[] calldata _timestamps, bytes[] calldata _signatures)
        external
        hasMinimumQuorum(_prices.length)
    {
        if (_prices.length != _timestamps.length || _prices.length != _signatures.length) {
            revert InvalidArrayLength();
        }

        // cache timestamp on the stack to save gas
        uint256 _lastTimestamp = lastTimestamp;
        uint256 _trackedPrice;
        uint256 bloom;

        for (uint256 i; i < _prices.length; ++i) {
            if (_timestamps[i] <= _lastTimestamp) revert InvalidTimestamp();
            if (_prices[i] < _trackedPrice) revert PricesNotOrdered();

            address _signer = _recover(_prices[i], _timestamps[i], _signatures[i]);

            // ecdsa lib already reverts with error `ECDSAInvalidSignature()` if signer == address(0)
            if (!authorizedNodes[_signer]) revert UnauthorizedNode();

            _trackedPrice = _prices[i];

            // Bloom filter for signer uniqueness
            uint8 mostSignificantByte = uint8(_addressToUint256(_signer) >> 152);
            if ((bloom >> mostSignificantByte) % 2 != 0) revert AlreadySigned();
            bloom += (2 ** mostSignificantByte);
        }

        // cache values
        uint256 _currentTimestamp = block.timestamp;
        uint256 _lastPrice = _median(_prices);

        // Update storage
        lastPrice = _lastPrice;
        lastTimestamp = _currentTimestamp;

        // emit event
        emit PriceUpdated(lastTimestamp, lastPrice);
    }

    function _recover(uint256 _price, uint256 _timestamp, bytes calldata _signature)
        internal
        view
        returns (address recoveredAddress)
    {
        bytes32 messageHash = keccak256(abi.encodePacked(_price, _timestamp, currencyPair));
        bytes32 digest = keccak256(bytes.concat("\x19Ethereum Signed Message:\n32", messageHash));

        uint8 v = uint8(_signature[64]);
        bytes32 r = bytes32(_signature[0:32]);
        bytes32 s = bytes32(_signature[32:64]);

        // no need to check the order of s or replay as none will work because of the timestamp check in the calling function
        recoveredAddress = ecrecover(digest, v, r, s);
        if (recoveredAddress == address(0)) revert InvalidSignature();
    }

    // Function to calculate the median of an array of values
    function _median(uint256[] memory values) internal pure returns (uint256) {
        if (values.length % 2 == 0) {
            uint256 m = values.length >> 1;
            uint256 middle1 = values[m - 1];
            uint256 middle2 = values[m];
            return (middle1 + middle2) >> 1;
        } else {
            return values[values.length >> 1];
        }
    }

    function _addressToUint256(address _addr) private pure returns (uint256) {
        return uint256(uint160(_addr));
    }
}
