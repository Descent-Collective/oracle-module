// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

//  ==========  External imports    ==========
import {Ownable} from "@openzeppelin-contracts/access/Ownable.sol";
import {IMedian} from "./interfaces/IMedian.sol";

contract OSM is Ownable {
    IMedian public median;
    uint256 oneHour = 1 hours;
    uint256 public lastUpdateHourStart;

    uint256 public current;
    uint256 public next;

    bool public stopped;

    error DelayNotElapsed();
    error UpdatesArePaused();

    event FeedUpdated(uint256 value);

    constructor(IMedian _median) Ownable(msg.sender) {
        median = _median;
    }

    modifier delayElasped() {
        if (block.timestamp < (lastUpdateHourStart + oneHour)) revert DelayNotElapsed();
        _;
    }

    modifier notStopped() {
        if (stopped) revert UpdatesArePaused();
        _;
    }

    function changeMedian(IMedian _median) external onlyOwner {
        median = _median;
    }

    function stop() external onlyOwner {
        stopped = true;
    }

    function start() external onlyOwner {
        stopped = false;
    }

    function void() external onlyOwner {
        current = 0;
        next = 0;
    }

    function update() external notStopped delayElasped {
        uint256 _lastPrice = median.lastPrice();

        next = current;
        current = _lastPrice;
        lastUpdateHourStart = block.timestamp - (block.timestamp % oneHour);
        emit FeedUpdated(lastUpdateHourStart);
    }
}
