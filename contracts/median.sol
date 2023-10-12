// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

//  ==========  External imports    ==========
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract Median is Initializable, OwnableUpgradeable {
    uint256 public minimumQuorum;
    bytes32 public currencyPair;
    uint128 internal lastTimestamp;
    uint128 internal lastPrice;

    mapping(address => bool) public authorizedNodes;
    uint256 public authorizedNodesCount;

    mapping(address => bool) public authorizedRelayers;
    uint256 public authorizedRelayersCount;

    struct PriceData {
        uint256 timestamp;
        uint256 price;
    }

    PriceData[] public priceHistory;

    // -- EVENTS --
    event AuthorizedNode(address indexed nodeAddress);
    event DeauthorizedNode(address indexed nodeAddress);
    event AuthorizedRelayer(address indexed relayerAddress);
    event DeauthorizedRelayer(address indexed relayerAddress);
    event MinimumQuorumUpdated(uint256 indexed minimumQuorum);
    event PriceUpdated(uint256 indexed timestamp, uint256 indexed price);

    // -- ERRORS --
    error OnlyAuthorizedNodes();
    error OnlyAuthorizedRelayers();
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

    modifier onlyAuthorizedRelayer() {
        if (!authorizedRelayers[msg.sender]) {
            revert OnlyAuthorizedRelayers();
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
    ) external onlyAuthorizedRelayer {
        if (
            _prices.length != _timestamps.length ||
            _prices.length != _v.length ||
            _prices.length != _r.length ||
            _prices.length != _s.length
        ) {
            revert InvalidArrayLength();
        }

        if (_prices.length < minimumQuorum) {
            revert NotEnoughAuthorizedNodes();
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
        lastTimestamp = uint128(_timestamps[_timestamps.length - 1]);

        priceHistory.push(PriceData(lastTimestamp, lastPrice));

        emit PriceUpdated(lastTimestamp, lastPrice);
    }

    function getMessageHash(
        uint256 _price,
        uint32 _timeStamp,
        bytes32 _pair
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_price, _timeStamp, _pair));
    }

    function recover(
        uint256 _price,
        uint32 _timeStamp,
        bytes32 _pair,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) internal pure returns (address) {
        bytes32 messageHash = getMessageHash(_price, _timeStamp, _pair);

        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        return ecrecover(prefixedHash, _v, _r, _s);
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
