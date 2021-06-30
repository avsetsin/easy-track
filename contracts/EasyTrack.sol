// SPDX-FileCopyrightText: 2021 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "./MotionSettings.sol";
import "./EasyTrackStorage.sol";
import "./OwnableUpgradeable.sol";
import "./EVMScriptFactoriesRegistry.sol";

import "./interfaces/IEVMScriptFactory.sol";
import "./interfaces/IEVMScriptExecutor.sol";

import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

contract EasyTrack is
    Initializable,
    EasyTrackStorage,
    UUPSUpgradeable,
    OwnableUpgradeable,
    MotionSettings,
    EVMScriptFactoriesRegistry
{
    event MotionCreated(
        uint256 indexed _motionId,
        address _creator,
        address indexed _evmScriptFactory,
        bytes _evmScriptCallData,
        bytes _evmScript
    );
    event MotionObjected(
        uint256 indexed _motionId,
        address indexed _objector,
        uint256 _weight,
        uint256 _votingPower
    );
    event MotionRejected(uint256 indexed _motionId);
    event MotionCanceled(uint256 indexed _motionId);
    event MotionEnacted(uint256 indexed _motionId);
    event EVMScriptExecutorChanged(address indexed _evmScriptExecutor);

    string private constant ERROR_ALREADY_OBJECTED = "ALREADY_OBJECTED";
    string private constant ERROR_NOT_ENOUGH_BALANCE = "NOT_ENOUGH_BALANCE";
    string private constant ERROR_NOT_CREATOR = "NOT_CREATOR";
    string private constant ERROR_MOTION_NOT_PASSED = "MOTION_NOT_PASSED";
    string private constant ERROR_UNEXPECTED_EVM_SCRIPT = "UNEXPECTED_EVM_SCRIPT";
    string private constant ERROR_MOTION_NOT_FOUND = "MOTION_NOT_FOUND";
    string private constant ERROR_MOTIONS_LIMIT_REACHED = "MOTIONS_LIMIT_REACHED";

    function __EasyTrack_init(address _governanceToken) public initializer {
        __Ownable_init();
        EasyTrackStorage.__EasyTrackStorage_init();
        governanceToken = IMiniMeToken(_governanceToken);
    }

    function createMotion(address _evmScriptFactory, bytes memory _evmScriptCallData)
        external
        returns (uint256 _newMotionId)
    {
        bytes memory evmScript =
            _createEVMScript(_evmScriptFactory, msg.sender, _evmScriptCallData);
        require(motions.length < motionsCountLimit, ERROR_MOTIONS_LIMIT_REACHED);

        Motion storage newMotion = motions.push();
        _newMotionId = ++lastMotionId;

        newMotion.id = _newMotionId;
        newMotion.creator = msg.sender;
        newMotion.startDate = block.timestamp;
        newMotion.snapshotBlock = block.number;

        newMotion.duration = motionDuration;
        newMotion.objectionsThreshold = objectionsThreshold;

        newMotion.evmScriptFactory = _evmScriptFactory;
        newMotion.evmScriptHash = keccak256(evmScript);

        motionIndicesByMotionId[_newMotionId] = motions.length;

        emit MotionCreated(
            _newMotionId,
            msg.sender,
            _evmScriptFactory,
            _evmScriptCallData,
            evmScript
        );
    }

    function cancelMotion(uint256 _motionId) external {
        Motion storage motion = _getMotion(_motionId);
        require(motion.creator == msg.sender, ERROR_NOT_CREATOR);
        _deleteMotion(_motionId);
        emit MotionCanceled(_motionId);
    }

    function enactMotion(uint256 _motionId, bytes memory _evmScriptCallData) external {
        Motion storage motion = _getMotion(_motionId);
        require(motion.startDate + motion.duration <= block.timestamp, ERROR_MOTION_NOT_PASSED);

        bytes memory evmScript =
            _createEVMScript(motion.evmScriptFactory, motion.creator, _evmScriptCallData);

        require(motion.evmScriptHash == keccak256(evmScript), ERROR_UNEXPECTED_EVM_SCRIPT);

        evmScriptExecutor.executeEVMScript(evmScript);
        _deleteMotion(_motionId);
        emit MotionEnacted(_motionId);
    }

    function objectToMotion(uint256 _motionId) external {
        Motion storage motion = _getMotion(_motionId);
        require(!objections[_motionId][msg.sender], ERROR_ALREADY_OBJECTED);
        objections[_motionId][msg.sender] = true;

        uint256 balance = governanceToken.balanceOfAt(msg.sender, motion.snapshotBlock);
        require(balance > 0, ERROR_NOT_ENOUGH_BALANCE);

        motion.objectionsAmount += balance;
        uint256 totalSupply = governanceToken.totalSupplyAt(motion.snapshotBlock);
        motion.objectionsAmountPct = (10000 * motion.objectionsAmount) / totalSupply;

        emit MotionObjected(_motionId, msg.sender, balance, totalSupply);

        if (motion.objectionsAmountPct > motion.objectionsThreshold) {
            _deleteMotion(_motionId);
            emit MotionRejected(_motionId);
        }
    }

    function canObjectToMotion(uint256 _motionId, address _objector) external view returns (bool) {
        Motion storage motion = _getMotion(_motionId);
        uint256 balance = governanceToken.balanceOfAt(_objector, motion.snapshotBlock);
        return balance > 0 && !objections[_motionId][_objector];
    }

    function setEVMScriptExecutor(address _evmScriptExecutor) external onlyOwner {
        evmScriptExecutor = IEVMScriptExecutor(_evmScriptExecutor);
    }

    function getMotions() external view returns (Motion[] memory) {
        return motions;
    }

    function _deleteMotion(uint256 _motionId) internal {
        uint256 index = motionIndicesByMotionId[_motionId] - 1;
        uint256 lastIndex = motions.length - 1;

        if (index != lastIndex) {
            Motion storage lastMotion = motions[lastIndex];
            motions[index] = lastMotion;
            motionIndicesByMotionId[lastMotion.id] = index + 1;
        }

        motions.pop();
        delete motionIndicesByMotionId[_motionId];
    }

    function _getMotion(uint256 _motionId)
        internal
        view
        motionExists(_motionId)
        returns (Motion storage)
    {
        return motions[motionIndicesByMotionId[_motionId] - 1];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    modifier motionExists(uint256 _motionId) {
        require(motionIndicesByMotionId[_motionId] > 0, ERROR_MOTION_NOT_FOUND);
        _;
    }
}