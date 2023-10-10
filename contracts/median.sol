// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

//  ==========  External imports    ==========
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "hardhat/console.sol";

contract Median is Initializable, OwnableUpgradeable {
    uint256 public minimumQuorum;
    bytes32 public currencyPair;
    uint256 internal lastTimestamp;
    uint256 internal lastPrice;

    mapping(address => bool) public authorizedNodes;
    uint256 public authorizedNodesCount;

    mapping(address => bool) public authorizedSigners;
    uint256 public authorizedSignersCount;

    struct PriceData {
        uint256 timestamp;
        uint256 price;
    }

    PriceData[] public priceHistory;

    // -- EVENTS --
    event AuthorizedNode(address indexed nodeAddress);
    event DeauthorizedNode(address indexed nodeAddress);
    event AuthorizedSigner(address indexed signerAddress);
    event DeauthorizedSigner(address indexed signerAddress);
    event MinimumQuorumUpdated(uint256 indexed minimumQuorum);
    event PriceUpdated(uint256 indexed timestamp, uint256 indexed price);

    // -- ERRORS --
    error OnlyAuthorizedNodes();
    error OnlyAuthorizedSigners();
    error NotEnoughAuthorizedNodes();
    error InvalidArrayLength();
    error InvalidSignature();
    error InvalidTimestamp();

    function initialize(
        uint256 _minimumQuorum,
        bytes32 _currencyPair
    ) public initializer {
        __Ownable_init_unchained(msg.sender);

        minimumQuorum = _minimumQuorum;
        currencyPair = _currencyPair;
    }

    modifier onlyAuthorizedNode() {
        if (!authorizedNodes[msg.sender]) {
            revert OnlyAuthorizedNodes();
        }
        _;
    }

    modifier onlyAuthorizedSigner() {
        if (!authorizedSigners[msg.sender]) {
            revert OnlyAuthorizedSigners();
        }
        _;
    }

    modifier hasMinimumQuorum() {
        if (authorizedNodesCount < minimumQuorum) {
            revert NotEnoughAuthorizedNodes();
        }
        _;
    }

    function authorizeNode(address _nodeAddress) external onlyOwner {
        if (!authorizedNodes[_nodeAddress]) {
            authorizedNodes[_nodeAddress] = true;
            authorizedNodesCount++;
        }

        emit AuthorizedNode(_nodeAddress);
    }

    function deauthorizeNode(address _nodeAddress) external onlyOwner {
        if (authorizedNodes[_nodeAddress]) {
            authorizedNodes[_nodeAddress] = false;
            authorizedNodesCount--;
        }

        emit DeauthorizedNode(_nodeAddress);
    }

    function authorizeSigner(address _signerAddress) external onlyOwner {
        if (!authorizedSigners[_signerAddress]) {
            authorizedSigners[_signerAddress] = true;
            authorizedSignersCount++;
        }

        emit AuthorizedSigner(_signerAddress);
    }

    function deauthorizeSigner(address _signerAddress) external onlyOwner {
        if (authorizedSigners[_signerAddress]) {
            authorizedSigners[_signerAddress] = false;
            authorizedSignersCount--;
        }

        emit DeauthorizedSigner(_signerAddress);
    }

    function updateMinimumQuorum(uint256 _minimumQuorum) external onlyOwner {
        minimumQuorum = _minimumQuorum;

        emit MinimumQuorumUpdated(_minimumQuorum);
    }

    function read() external view returns (uint256, uint256) {
        return (lastTimestamp, lastPrice);
    }

    function update(
        uint256[] calldata _prices,
        uint32[] calldata _timestamps,
        uint8[] calldata _v,
        bytes32[] calldata _r,
        bytes32[] calldata _s
    ) external onlyAuthorizedSigner hasMinimumQuorum {
        if (
            _prices.length != _timestamps.length ||
            _prices.length != _v.length ||
            _prices.length != _r.length ||
            _prices.length != _s.length
        ) {
            revert InvalidArrayLength();
        }

        for (uint256 i = 0; i < _prices.length; i++) {
            if (_timestamps[i] <= lastTimestamp) {
                revert InvalidTimestamp();
            }

            address signer = recover(
                _prices[i],
                _timestamps[i],
                currencyPair,
                _v[i],
                _r[i],
                _s[i]
            );

            if (signer == address(0) || !authorizedNodes[signer]) {
                revert InvalidSignature();
            }
        }

        uint256[] memory sortedPrices = sort(_prices);

        lastPrice = uint128(median(sortedPrices));
        lastTimestamp = _timestamps[_timestamps.length - 1];

        priceHistory.push(PriceData(lastTimestamp, lastPrice));

        emit PriceUpdated(lastTimestamp, lastPrice);
    }

    function recover(
        uint256 _price,
        uint32 _timeStamp,
        bytes32 _pair,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal pure returns (address) {
        bytes32 messageHash = keccak256(
            abi.encodePacked(_price, _timeStamp, _pair)
        );
        return ecrecover(messageHash, _v, _r, _s);
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
    function sort(
        uint256[] memory data
    ) internal pure returns (uint256[] memory) {
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
