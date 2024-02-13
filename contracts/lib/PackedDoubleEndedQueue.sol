// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (utils/structs/DoubleEndedQueue.sol)
// Modified by Pandora Labs to support native packed operations
pragma solidity ^0.8.20;

/**
 * @dev A sequence of items with the ability to efficiently push and pop items (i.e. insert and remove) on both ends of
 * the sequence (called front and back). Among other access patterns, it can be used to implement efficient LIFO and
 * FIFO queues. Storage use is optimized, and all operations are O(1) constant time. This includes {clear}, given that
 * the existing queue contents are left in storage.
 *
 * The struct is called `Bytes32Deque`. Other types can be cast to and from `bytes32`. This data structure can only be
 * used in storage, and not in memory.
 * ```solidity
 * DoubleEndedQueue.Bytes32Deque queue;
 * ```
 */
library PackedDoubleEndedQueue {
  uint128 constant SLOT_MASK = (1 << 64) - 1;
  uint128 constant INDEX_MASK = SLOT_MASK << 64;

  uint256 constant SLOT_0_MASK = (1 << 16) - 1;
  uint256 constant SLOT_1_MASK = SLOT_0_MASK << 16;
  uint256 constant SLOT_2_MASK = SLOT_0_MASK << (16 * 2);
  uint256 constant SLOT_3_MASK = SLOT_0_MASK << (16 * 3);
  uint256 constant SLOT_4_MASK = SLOT_0_MASK << (16 * 4);
  uint256 constant SLOT_5_MASK = SLOT_0_MASK << (16 * 5);
  uint256 constant SLOT_6_MASK = SLOT_0_MASK << (16 * 6);
  uint256 constant SLOT_7_MASK = SLOT_0_MASK << (16 * 7);
  uint256 constant SLOT_8_MASK = SLOT_0_MASK << (16 * 8);
  uint256 constant SLOT_9_MASK = SLOT_0_MASK << (16 * 9);
  uint256 constant SLOT_10_MASK = SLOT_0_MASK << (16 * 10);
  uint256 constant SLOT_11_MASK = SLOT_0_MASK << (16 * 11);
  uint256 constant SLOT_12_MASK = SLOT_0_MASK << (16 * 12);
  uint256 constant SLOT_13_MASK = SLOT_0_MASK << (16 * 13);
  uint256 constant SLOT_14_MASK = SLOT_0_MASK << (16 * 14);
  uint256 constant SLOT_15_MASK = SLOT_0_MASK << (16 * 15);

  /**
   * @dev An operation (e.g. {front}) couldn't be completed due to the queue being empty.
   */
  error QueueEmpty();

  /**
   * @dev A push operation couldn't be completed due to the queue being full.
   */
  error QueueFull();

  /**
   * @dev An operation (e.g. {at}) couldn't be completed due to an index being out of bounds.
   */
  error QueueOutOfBounds();

  /**
   * @dev Invalid slot.
   */
  error InvalidSlot();

  /**
   * @dev Indices and slots are 64 bits to fit within a single storage slot.
   *
   * Struct members have an underscore prefix indicating that they are "private" and should not be read or written to
   * directly. Use the functions provided below instead. Modifying the struct manually may violate assumptions and
   * lead to unexpected behavior.
   *
   * The first item is at data[begin] and the last item is at data[end - 1]. This range can wrap around.
   */
  struct Uint16Deque {
    uint64 _beginIndex;
    uint64 _beginSlot;
    uint64 _endIndex;
    uint64 _endSlot;
    mapping(uint64 index => uint256) _data;
  }

  /**
   * @dev Removes the item at the end of the queue and returns it.
   *
   * Reverts with {QueueEmpty} if the queue is empty.
   */
  function popBack(
    Uint16Deque storage deque
  ) internal returns (uint256 value) {
    unchecked {
      uint64 backIndex = deque._endIndex;
      uint64 backSlot = deque._endSlot;

      if (backIndex == deque._beginIndex && backSlot == deque._beginSlot) revert QueueEmpty();

      if (backSlot <= 0) {
        --backIndex;
        backSlot = 15;
      } else {
        --backSlot;
      }

      uint256 data = deque._data[backIndex];

      value = _getEntry(data, backSlot);
      deque._data[backIndex] = _setData(data, backSlot, 0);

      deque._endIndex = backIndex;
      deque._endSlot = backSlot;
    }
  }

  /**
   * @dev Inserts an item at the beginning of the queue.
   *
   * Reverts with {QueueFull} if the queue is full.
   */
  function pushFront(Uint16Deque storage deque, uint16 value) internal {
    unchecked {
      uint64 frontIndex = deque._beginIndex;
      uint64 frontSlot = deque._beginSlot;

      if (frontSlot <= 0) {
        --frontIndex;
        frontSlot = 15;
      } else {
        --frontSlot;
      }

      if (frontIndex == deque._endIndex) revert QueueFull();

      deque._data[frontIndex] = _setData(deque._data[frontIndex], frontSlot, value);
      deque._beginIndex = frontIndex;
      deque._beginSlot = frontSlot;
    }
  }

  /**
   * @dev Return the item at a position in the queue given by `index`, with the first item at 0 and last item at
   * `length(deque) - 1`.
   *
   * Reverts with `QueueOutOfBounds` if the index is out of bounds.
   */
  function at(
    Uint16Deque storage deque,
    uint256 index_
  ) internal view returns (uint256 value) {
    if (index_ >= length(deque) * 16) revert QueueOutOfBounds();

    unchecked {
      return _getEntry(
        deque._data[deque._beginIndex + uint64(deque._beginSlot + (index_ % 16)) / 16 + uint64(index_ / 16)], 
        uint64(((deque._beginSlot + index_) % 16))
      );
    }
  }

  /**
   * @dev Returns the number of items in the queue.
   */
  function length(Uint16Deque storage deque) internal view returns (uint256) {
    unchecked {
      return (16 - deque._beginSlot) + deque._endSlot + deque._endIndex * 16 - deque._beginIndex * 16 - 16;
    }
  }

  /**
   * @dev Returns true if the queue is empty.
   */
  function empty(Uint16Deque storage deque) internal view returns (bool) {
    return deque._endSlot == deque._beginSlot && deque._endIndex == deque._beginIndex;
  }

  function _setData(uint256 data_, uint64 slot_, uint16 value) private pure returns (uint256) {
    return (data_ & (~_getSlotMask(slot_))) + (uint256(value) << (16 * slot_));
  }

  function _getEntry(uint256 data, uint64 slot_) private pure returns (uint16) {
    return uint16((data & _getSlotMask(slot_)) >> (16 * slot_));
  }

  function _getSlotMask(uint64 slot_) private pure returns (uint256) {
    if (slot_ == 0) {
        return SLOT_0_MASK;
    } else if (slot_ == 1) {
        return SLOT_1_MASK;
    } else if (slot_ == 2) {
        return SLOT_2_MASK;
    } else if (slot_ == 3) {
        return SLOT_3_MASK;
    } else if (slot_ == 4) {
        return SLOT_4_MASK;
    } else if (slot_ == 5) {
        return SLOT_5_MASK;
    } else if (slot_ == 6) {
        return SLOT_6_MASK;
    } else if (slot_ == 7) {
        return SLOT_7_MASK;
    } else if (slot_ == 8) {
        return SLOT_8_MASK;
    } else if (slot_ == 9) {
        return SLOT_9_MASK;
    } else if (slot_ == 10) {
        return SLOT_10_MASK;
    } else if (slot_ == 11) {
        return SLOT_11_MASK;
    } else if (slot_ == 12) {
        return SLOT_12_MASK;
    } else if (slot_ == 13) {
        return SLOT_13_MASK;
    } else if (slot_ == 14) {
        return SLOT_14_MASK;
    } else if (slot_ == 15) {
        return SLOT_15_MASK;
    } else {
        revert InvalidSlot();
    }
  }
}
