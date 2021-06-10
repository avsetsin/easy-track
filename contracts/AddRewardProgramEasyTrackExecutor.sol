// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>

// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "./TrustedAddress.sol";
import "./EasyTrackExecutor.sol";
import "./TopUpRewardProgramEasyTrackExecutor.sol";

contract AddRewardProgramEasyTrackExecutor is EasyTrackExecutor, TrustedAddress {
    TopUpRewardProgramEasyTrackExecutor public topUpRewardProgramEasyTrackExecutor;

    constructor(
        address _easyTracksRegistry,
        address _topUpRewardProgramEasyTrackExecutor,
        address _allowedCaller
    ) EasyTrackExecutor(_easyTracksRegistry) TrustedAddress(_allowedCaller) {
        topUpRewardProgramEasyTrackExecutor = TopUpRewardProgramEasyTrackExecutor(
            _topUpRewardProgramEasyTrackExecutor
        );
    }

    function _beforeCreateMotionGuard(address _caller, bytes memory _data)
        internal
        view
        override
        onlyTrustedAddress(_caller)
    {
        address _rewardProgram = _decodeMotionData(_data);
        require(
            !topUpRewardProgramEasyTrackExecutor.isAllowed(_rewardProgram),
            "REWARD_PROGRAM_ALREADY_ADDED"
        );
    }

    function _beforeCancelMotionGuard(
        address _caller,
        bytes memory _motionData,
        bytes memory _cancelData
    ) internal view override onlyTrustedAddress(_caller) {}

    function _execute(bytes memory _motionData, bytes memory _enactData)
        internal
        override
        returns (bytes memory)
    {
        address _rewardProgram = _decodeMotionData(_motionData);
        topUpRewardProgramEasyTrackExecutor.addRewardProgram(_rewardProgram);
    }

    function _decodeMotionData(bytes memory _motionData)
        private
        pure
        returns (address _rewardProgram)
    {
        (_rewardProgram) = abi.decode(_motionData, (address));
    }
}