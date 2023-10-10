// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IMedian {
    // Emitted when a new node is authorized
    event AuthorizedNode(address indexed nodeAddress);

    // Emitted when a node is deauthorized
    event DeauthorizedNode(address indexed nodeAddress);

    // Emitted when a new signer is authorized
    event AuthorizedSigner(address indexed signerAddress);

    // Emitted when a signer is deauthorized
    event DeauthorizedSigner(address indexed signerAddress);

    // Emitted when the price is updated
    event PriceUpdated(uint256 indexed timestamp, uint256 indexed price);

    // Emitted when the minimum quorum is updated
    event MinimumQuorumUpdated(uint256 indexed minimumQuorum);

    // Authorizes a node to submit prices to clients
    function authorizeNode(address nodeAddress) external;

    // Deauthorizes a node to submit prices to clients
    function deauthorizeNode(address nodeAddress) external;

    // Authorizes a signer to submit prices
    function authorizeSigner(address signerAddress) external;

    // Deauthorizes a signer to submit prices
    function deauthorizeSigner(address signerAddress) external;

    // Updates the minimum quorum
    function updateMinimumQuorum(uint256 minimumQuorum) external;

    // Updates the price
    function updatePrice(
        uint256[] calldata _prices,
        uint32[] calldata _timestamps,
        uint8[] calldata _v,
        bytes32[] calldata _r,
        bytes32[] calldata _s
    ) external;

    // Reads the price and the timestamp
    function read() external view returns (uint256, uint256);
}
