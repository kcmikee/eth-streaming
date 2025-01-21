// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract EthStreaming is Ownable {
  uint256 public immutable unlockTime;

  struct Stream {
    uint256 cap;
    uint256 timeOfLastWithdrawal;
  }

  mapping(address => Stream) public streams;

  event AddStream(address recipient, uint256 cap);
  event Withdraw(address recipient, uint256 amount);

  constructor(
    uint256 _unlockTime
  ) Ownable(msg.sender) {
    unlockTime = _unlockTime;
  }

  receive() external payable { }

  function addStream(address recipient, uint256 cap) external onlyOwner {
    streams[recipient] = Stream(cap, 0);
    emit AddStream(recipient, cap);
  }

  function withdraw(
    uint256 amt
  ) external {
    Stream storage stream = streams[msg.sender];
    require(stream.cap > 0, "No available stream ");
    require(address(this).balance >= amt, "Insufficient bal ");

    uint256 elapsed = block.timestamp - stream.timeOfLastWithdrawal;
    uint256 unlockedAmount;

    if (stream.timeOfLastWithdrawal == 0) {
      unlockedAmount = stream.cap;
    } else {
      unlockedAmount = (elapsed * stream.cap) / unlockTime;
      if (unlockedAmount > stream.cap) {
        unlockedAmount = stream.cap;
      }
    }

    require(amt <= unlockedAmount, "Amount exceeds unlocked balance");

    if (amt == unlockedAmount) {
      stream.timeOfLastWithdrawal = block.timestamp;
    } else {
      stream.timeOfLastWithdrawal =
        block.timestamp - (((unlockedAmount - amt) * unlockTime) / stream.cap);
    }

    (bool success,) = msg.sender.call{ value: amt }("");
    require(success, "Transfer failed");

    emit Withdraw(msg.sender, amt);
  }
}
