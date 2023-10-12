// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IMedian {
    // Emitted when a new node is authorized
    event AuthorizedNode(address indexed nodeAddress);

    // Emitted when a node is deauthorized
    event DeauthorizedNode(address indexed nodeAddress);

    // Emitted when a new relayer is authorized
    event AuthorizedRelayer(address indexed relayerAddress);

    // Emitted when a relayer is deauthorized
    event DeauthorizedRelayer(address indexed relayerAddress);

    // Emitted when the price is updated
    event PriceUpdated(uint256 indexed timestamp, uint256 indexed price);

    // Emitted when the minimum quorum is updated
    event MinimumQuorumUpdated(uint256 indexed minimumQuorum);

    // Authorizes a node to submit prices to clients
    function authorizeNode(address nodeAddress) external;

    // Deauthorizes a node to submit prices to clients
    function deauthorizeNode(address nodeAddress) external;

    // Authorizes a relayer to submit prices
    function authorizeRelayer(address signerAddress) external;

    // Deauthorizes a relayer to submit prices
    function deauthorizeRelayer(address signerAddress) external;

    // Updates the minimum quorum
    function updateMinimumQuorum(uint256 minimumQuorum) external;

    // Updates the price
    function updatePrice(
        uint256[] memory _prices,
        uint32[] memory _timestamps,
        bytes[] memory _signatures
    ) external;

    // Reads the price and the timestamp
    function read() external view returns (uint128, uint128);
}
