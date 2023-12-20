// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IMedian {
    // -- CUSTOM TYPES --
    struct PriceData {
        uint256 timestamp;
        uint256 price;
    }

    // -- ERRORS --
    error NotEnoughPrices();
    error InvalidArrayLength();
    error UnauthorizedNode();
    error InvalidTimestamp();
    error PricesNotOrdered();
    error InvalidQuorum();
    error InvalidSignature();
    error AlreadySigned();
    error AddressZero();
    error NodeSlotTaken();

    // -- EVENTS --
    // Emitted when a node is authorized
    event AuthorizedNode(address indexed addr);

    // Emitted when a node is deauthorized
    event DeauthorizedNode(address indexed addr);

    // Emitted when the price is updated
    event PriceUpdated(uint256 indexed timestamp, uint256 indexed price);

    // Emitted when the minimum quorum is updated
    event MinimumQuorumUpdated(uint256 indexed minimumQuorum);

    // -- INTERFACE FUNCTIONS --
    // Authorizes an address to sign prices
    function authorizeNode(address addr) external;

    // Deauthorizes an address to sign prices
    function deauthorizeNode(address addr) external;

    // Updates the minimum quorum
    function updateMinimumQuorum(uint256 minimumQuorum) external;

    // Updates the price
    function update(uint256[] calldata _prices, uint256[] calldata _timestamps, bytes[] calldata _signatures)
        external;

    // Reads the price and the timestamp
    function read() external view returns (uint256, uint256);

    // Reads historical price data
    function priceHistory(uint256 index) external view returns (uint256, uint256);

    // Reads the currency pair bytes32 value
    function currencyPair() external view returns (bytes32);

    // Reads the current minimum quorum
    function minimumQuorum() external view returns (uint256);

    // Reads the current number of authorized nodes
    function authorizedNodesCount() external view returns (uint256);

    // Returns true if addr is a valid node
    function authorizedNodes(address addr) external view returns (bool);
}
