// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "./TrustedCaller.sol";

/// @title Registry of allowed reward programs
/// @notice Stores list of addresses with reward programs
contract RewardProgramsRegistry is TrustedCaller {
    // -------------
    // EVENTS
    // -------------
    event RewardProgramAdded(address indexed _rewardProgram);
    event RewardProgramRemoved(address indexed _rewardProgram);

    // -------------
    // ERRORS
    // -------------
    string private constant ERROR_REWARD_PROGRAM_ALREADY_ADDED = "REWARD_PROGRAM_ALREADY_ADDED";
    string private constant ERROR_REWARD_PROGRAM_NOT_FOUND = "REWARD_PROGRAM_NOT_FOUND";

    // -------------
    // VARIABLES
    // -------------

    /// @dev List of allowed reward program addresses
    address[] public rewardPrograms;

    // Position of the reward program in the `rewardPrograms` array,
    // plus 1 because index 0 means a value is not in the set.
    mapping(address => uint256) private rewardProgramIndices;

    // -------------
    // CONSTRUCTOR
    // -------------

    constructor(address _trustedCaller) TrustedCaller(_trustedCaller) {}

    // -------------
    // EXTERNAL METHODS
    // -------------

    /// @notice Adds address to list of allowed reward programs
    function addRewardProgram(address _rewardProgram) external onlyTrustedCaller(msg.sender) {
        require(rewardProgramIndices[_rewardProgram] == 0, ERROR_REWARD_PROGRAM_ALREADY_ADDED);

        rewardPrograms.push(_rewardProgram);
        rewardProgramIndices[_rewardProgram] = rewardPrograms.length;
        emit RewardProgramAdded(_rewardProgram);
    }

    /// @notice Removes address from list of allowed reward programs
    /// @dev To delete a reward program from the rewardPrograms array in O(1), we swap the element to delete with the last one in
    /// the array, and then remove the last element (sometimes called as 'swap and pop').
    function removeRewardProgram(address _rewardProgram) external onlyTrustedCaller(msg.sender) {
        uint256 index = _gerRewardProgramIndex(_rewardProgram);
        uint256 lastIndex = rewardPrograms.length - 1;

        if (index != lastIndex) {
            address lastRewardProgram = rewardPrograms[lastIndex];
            rewardPrograms[index] = lastRewardProgram;
            rewardProgramIndices[lastRewardProgram] = index + 1;
        }

        rewardPrograms.pop();
        delete rewardProgramIndices[_rewardProgram];
        emit RewardProgramRemoved(_rewardProgram);
    }

    /// @notice Returns if passed address are listed as reward program in the registry
    function isRewardProgram(address _maybeRewardProgram) external view returns (bool) {
        return rewardProgramIndices[_maybeRewardProgram] > 0;
    }

    /// @notice Returns current list of reward programs
    function getRewardPrograms() external view returns (address[] memory) {
        return rewardPrograms;
    }

    // ------------------
    // PRIVATE METHODS
    // ------------------

    function _gerRewardProgramIndex(address _evmScriptFactory)
        private
        view
        returns (uint256 _index)
    {
        _index = rewardProgramIndices[_evmScriptFactory];
        require(_index > 0, ERROR_REWARD_PROGRAM_NOT_FOUND);
        _index -= 1;
    }
}
