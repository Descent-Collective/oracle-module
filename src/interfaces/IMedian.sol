// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface IMedian {
    struct PriceData {
        uint128 timestamp;
        uint128 price;
    }

    // -- ERRORS --
    error NotEnoughPrices();
    error OnlyAuthorizedRelayers();
    error InvalidArrayLength();
    error InvalidSignature();
    error InvalidTimestamp();

    // Emitted when a new signer is authorized
    event AuthorizedRelayer(address indexed signerAddress);

    // Emitted when a signer is deauthorized
    event DeauthorizedRelayer(address indexed signerAddress);

    // Emitted when the price is updated
    event PriceUpdated(uint256 indexed timestamp, uint256 indexed price);

    // Emitted when the minimum quorum is updated
    event MinimumQuorumUpdated(uint256 indexed minimumQuorum);

    // Authorizes a signer to submit prices
    function authorizeRelayer(address signerAddress) external;

    // Deauthorizes a signer to submit prices
    function deauthorizeRelayer(address signerAddress) external;

    // Updates the minimum quorum
    function updateMinimumQuorum(uint32 minimumQuorum) external;

    // Updates the price
    function update(
        uint256[] calldata _prices,
        uint64[] calldata _timestamps,
        uint8[] calldata _v,
        bytes32[] calldata _r,
        bytes32[] calldata _s
    ) external;

    // Reads the price and the timestamp
    function read() external view returns (uint256, uint256);

    // Reads historical price data
    function priceHistory(uint256 index) external view returns (uint128, uint128);

    // Reads the currency pair bytes32 value
    function currencyPair() external view returns (bytes32);

    // Reads the current minimum quorum
    function minimumQuorum() external view returns (uint32);

    // Reads the current number of authorized relayers
    function authorizedRelayersCount() external view returns (uint32);

    // Returns true if addr is a valid relayer
    function authorizedRelayers(address addr) external view returns (bool);
}
