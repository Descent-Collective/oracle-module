## Oracle Module

- Get [Foundry](https://book.getfoundry.sh/)

## To test

```shell
$ forge test -vvv --gas-report
```

## To deploy locally to anvil

Run

```shell
$ anvil
```

Note: Be sure to set `PRIVATE_KEY` variable in .env to be one of the anvil local private keys with eth balance

Then

```shell
$ source .env
$ forge script script/median.s.sol:MedianScript --fork-url http://localhost:8545 --broadcast -vvvv
```

## To deploy to a public network

```shell
$ source .env
$ forge script script/median.s.sol:MedianScript --rpc-url $GOERLI_RPC_URL --broadcast --verify -vvvv
```

Note: Can remove `--broadcast and `--verify` to simulate the deployment script locally without actually broadcasting it to the network

## Foundry Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test -vvv --gas-report
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
