// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IAggregatorInterface {
  function latestAnswer(bytes32 key) external view returns (uint160);

  function latestTimestamp(bytes32 key) external view returns (uint256);

  function latestRound(bytes32 key) external view returns (uint256);

  function getAnswer(bytes32 key, uint256 roundId) external view returns (uint160);

  event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

  event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
} 