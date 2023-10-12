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
        uint128 timestamp;
        uint128 price;
    }

    PriceData[] public priceHistory;

    // -- EVENTS --
    event AuthorizedNode(address indexed nodeAddress);
    event DeauthorizedNode(address indexed nodeAddress);
    event AuthorizedRelayer(address indexed relayerAddress);
    event DeauthorizedRelayer(address indexed relayerAddress);
    event MinimumQuorumUpdated(uint256 indexed minimumQuorum);
    event PriceUpdated(uint128 indexed timestamp, uint128 indexed price);

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

    function read() external view returns (uint128, uint128) {
        return (lastTimestamp, lastPrice);
    }

    function update(
        uint256[] memory _prices,
        uint32[] memory _timestamps,
        bytes[] memory _signatures
    ) external onlyAuthorizedRelayer {
        if (
            _prices.length != _timestamps.length ||
            _prices.length != _signatures.length
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
                _signatures[i]
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
        bytes memory sig
    ) internal pure returns (address) {
        bytes32 messageHash = getMessageHash(_price, _timeStamp, _pair);

        bytes32 prefixedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        (bytes32 r, bytes32 s, uint8 v) = splitSignature(sig);

        return ecrecover(prefixedHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (sig.length != 65) {
            revert InvalidSignature();
        }

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
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
