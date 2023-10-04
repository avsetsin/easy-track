// SPDX-FileCopyrightText: 2022 Lido <info@lido.fi>
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

interface IEasyTrack {
    function evmScriptExecutor() external view returns (address);
}

interface IAllowedRecipientsRegistry {
    function addRecipient(address _recipient, string memory _title) external;

    function addToken(address _token) external;

    function renounceRole(bytes32 role, address account) external;

    function isRecipientAllowed(address _recipient) external view returns (bool);

    function isTokenAllowed(address _token) external view returns (bool);

    function setLimitParameters(uint256 _limit, uint256 _periodDurationMonths) external;

    function getLimitParameters() external view returns (uint256, uint256);

    function updateSpentAmount(uint256 _payoutAmount, address _token) external;

    function spendableBalance() external view returns (uint256);

    function hasRole(bytes32 role, address account) external view returns (bool);

    function getAllowedRecipients() external view returns (address[] memory);

    function getAllowedTokens() external view returns (address[] memory);

    function bokkyPooBahsDateTimeContract() external view returns (address);
}

interface ITopUpAllowedRecipients {
    function token() external view returns (address);

    function finance() external view returns (address);

    function easyTrack() external view returns (IEasyTrack);

    function trustedCaller() external view returns (address);

    function allowedRecipientsRegistry() external view returns (address);
}

interface IAddAllowedRecipient {
    function trustedCaller() external view returns (address);

    function allowedRecipientsRegistry() external view returns (address);
}

interface IRemoveAllowedRecipient {
    function trustedCaller() external view returns (address);

    function allowedRecipientsRegistry() external view returns (address);
}

interface IAllowedRecipientsFactory {
    function deployAllowedRecipientsRegistry(
        address _admin,
        address[] memory _addRecipientToAllowedListRoleHolders,
        address[] memory _removeRecipientFromAllowedListRoleHolders,
        address[] memory _addTokenToAllowedListRoleHolders,
        address[] memory _removeTokenFromAllowedListRoleHolders,
        address[] memory _setLimitParametersRoleHolders,
        address[] memory _updateSpentAmountRoleHolders,
        address bokkyPooBahsDateTimeContract
    ) external returns (IAllowedRecipientsRegistry);

    function deployTopUpAllowedRecipients(
        address _trustedCaller,
        address _allowedRecipientsRegistry,
        address _token,
        address _finance,
        IEasyTrack _easyTrack
    ) external returns (ITopUpAllowedRecipients);

    function deployAddAllowedRecipient(address _trustedCaller, address _allowedRecipientsRegistry)
        external
        returns (IAddAllowedRecipient);

    function deployRemoveAllowedRecipient(
        address _trustedCaller,
        address _allowedRecipientsRegistry
    ) external returns (IRemoveAllowedRecipient);
}

contract AllowedRecipientsBuilder {
    IEasyTrack public immutable easyTrack;
    address public immutable finance;
    address public immutable evmScriptExecutor;
    address public immutable admin;
    address public immutable bokkyPooBahsDateTimeContract;
    IAllowedRecipientsFactory public immutable factory;

    bytes32 public constant ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE =
        keccak256("ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE");
    bytes32 public constant REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE =
        keccak256("REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE");
    bytes32 public constant ADD_TOKEN_TO_ALLOWED_LIST_ROLE =
        keccak256("ADD_TOKEN_TO_ALLOWED_LIST_ROLE");
    bytes32 public constant REMOVE_TOKEN_FROM_ALLOWED_LIST_ROLE =
        keccak256("REMOVE_TOKEN_FROM_ALLOWED_LIST_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant SET_PARAMETERS_ROLE = keccak256("SET_PARAMETERS_ROLE");
    bytes32 public constant UPDATE_SPENT_AMOUNT_ROLE = keccak256("UPDATE_SPENT_AMOUNT_ROLE");

    constructor(
        IAllowedRecipientsFactory _factory,
        address _admin,
        IEasyTrack _easytrack,
        address _finance,
        address _bokkyPooBahsDateTimeContract
    ) {
        factory = _factory;
        evmScriptExecutor = _easytrack.evmScriptExecutor();
        admin = _admin;
        easyTrack = _easytrack;
        finance = _finance;
        bokkyPooBahsDateTimeContract = _bokkyPooBahsDateTimeContract;
    }

    function deployAllowedRecipientsRegistry(
        uint256 _limit,
        uint256 _periodDurationMonths,
        address[] memory _tokens,
        address[] memory _recipients,
        string[] memory _titles,
        uint256 _spentAmount,
        bool _grantRightsToEVMScriptExecutor
    ) public returns (IAllowedRecipientsRegistry registry) {
        require(_recipients.length == _titles.length, "Recipients data length mismatch");
        require(_spentAmount <= _limit, "_spentAmount must be lower or equal to limit");

        address[] memory addRecipientAndTokenToAllowedListRoleHolders = new address[](
            _grantRightsToEVMScriptExecutor ? 3 : 2
        );
        addRecipientAndTokenToAllowedListRoleHolders[0] = admin;
        addRecipientAndTokenToAllowedListRoleHolders[1] = address(this);
        if (_grantRightsToEVMScriptExecutor) {
            addRecipientAndTokenToAllowedListRoleHolders[2] = evmScriptExecutor;
        }
        address[] memory removeRecipientAndTokenFromAllowedListRoleHolders = new address[](
            _grantRightsToEVMScriptExecutor ? 2 : 1
        );
        removeRecipientAndTokenFromAllowedListRoleHolders[0] = admin;
        if (_grantRightsToEVMScriptExecutor) {
            removeRecipientAndTokenFromAllowedListRoleHolders[1] = evmScriptExecutor;
        }
        address[] memory setLimitParametersRoleHolders = new address[](2);
        setLimitParametersRoleHolders[0] = admin;
        setLimitParametersRoleHolders[1] = address(this);
        address[] memory updateSpentAmountRoleHolders = new address[](3);
        updateSpentAmountRoleHolders[0] = admin;
        updateSpentAmountRoleHolders[1] = evmScriptExecutor;
        updateSpentAmountRoleHolders[2] = address(this);

        registry = factory.deployAllowedRecipientsRegistry(
            admin,
            addRecipientAndTokenToAllowedListRoleHolders,
            removeRecipientAndTokenFromAllowedListRoleHolders,
            addRecipientAndTokenToAllowedListRoleHolders,
            removeRecipientAndTokenFromAllowedListRoleHolders,
            setLimitParametersRoleHolders,
            updateSpentAmountRoleHolders,
            bokkyPooBahsDateTimeContract
        );

        assert(registry.bokkyPooBahsDateTimeContract() == bokkyPooBahsDateTimeContract);

        for (uint256 i = 0; i < _recipients.length; i++) {
            registry.addRecipient(_recipients[i], _titles[i]);
        }
        registry.renounceRole(ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE, address(this));

        assert(registry.getAllowedRecipients().length == _recipients.length);

        for (uint256 i = 0; i < _recipients.length; i++) {
            assert(registry.isRecipientAllowed(_recipients[i]));
        }

        for (uint256 i = 0; i < _tokens.length; i++) {
            registry.addToken(_tokens[i]);
        }
        registry.renounceRole(ADD_TOKEN_TO_ALLOWED_LIST_ROLE, address(this));

        assert(registry.getAllowedTokens().length == _tokens.length);

        for (uint256 i = 0; i < _tokens.length; i++) {
            assert(registry.isTokenAllowed(_tokens[i]));
        }

        registry.setLimitParameters(_limit, _periodDurationMonths);
        registry.renounceRole(SET_PARAMETERS_ROLE, address(this));

        (uint256 registryLimit, uint256 registryPeriodDuration) = registry.getLimitParameters();
        assert(registryLimit == _limit);
        assert(registryPeriodDuration == _periodDurationMonths);

        registry.updateSpentAmount(_spentAmount, address(0));
        registry.renounceRole(UPDATE_SPENT_AMOUNT_ROLE, address(this));

        assert(registry.spendableBalance() == _limit - _spentAmount);

        assert(registry.hasRole(ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE, admin));
        assert(registry.hasRole(REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE, admin));
        assert(registry.hasRole(ADD_TOKEN_TO_ALLOWED_LIST_ROLE, admin));
        assert(registry.hasRole(REMOVE_TOKEN_FROM_ALLOWED_LIST_ROLE, admin));
        assert(registry.hasRole(SET_PARAMETERS_ROLE, admin));
        assert(registry.hasRole(UPDATE_SPENT_AMOUNT_ROLE, admin));
        assert(registry.hasRole(DEFAULT_ADMIN_ROLE, admin));

        if (_grantRightsToEVMScriptExecutor) {
            assert(registry.hasRole(ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE, evmScriptExecutor));
            assert(registry.hasRole(REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE, evmScriptExecutor));
            assert(registry.hasRole(ADD_TOKEN_TO_ALLOWED_LIST_ROLE, evmScriptExecutor));
            assert(registry.hasRole(REMOVE_TOKEN_FROM_ALLOWED_LIST_ROLE, evmScriptExecutor));
        } else {
            assert(!registry.hasRole(ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE, evmScriptExecutor));
            assert(!registry.hasRole(REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE, evmScriptExecutor));
            assert(!registry.hasRole(ADD_TOKEN_TO_ALLOWED_LIST_ROLE, evmScriptExecutor));
            assert(!registry.hasRole(REMOVE_TOKEN_FROM_ALLOWED_LIST_ROLE, evmScriptExecutor));
        }
        assert(registry.hasRole(UPDATE_SPENT_AMOUNT_ROLE, evmScriptExecutor));
        assert(!registry.hasRole(SET_PARAMETERS_ROLE, evmScriptExecutor));
        assert(!registry.hasRole(DEFAULT_ADMIN_ROLE, evmScriptExecutor));

        assert(!registry.hasRole(ADD_RECIPIENT_TO_ALLOWED_LIST_ROLE, address(this)));
        assert(!registry.hasRole(REMOVE_RECIPIENT_FROM_ALLOWED_LIST_ROLE, address(this)));
        assert(!registry.hasRole(ADD_TOKEN_TO_ALLOWED_LIST_ROLE, address(this)));
        assert(!registry.hasRole(REMOVE_TOKEN_FROM_ALLOWED_LIST_ROLE, address(this)));
        assert(!registry.hasRole(SET_PARAMETERS_ROLE, address(this)));
        assert(!registry.hasRole(UPDATE_SPENT_AMOUNT_ROLE, address(this)));
        assert(!registry.hasRole(DEFAULT_ADMIN_ROLE, address(this)));
    }

    function deployTopUpAllowedRecipients(
        address _trustedCaller,
        address _allowedRecipientsRegistry,
        address _token
    ) public returns (ITopUpAllowedRecipients topUpAllowedRecipients) {
        topUpAllowedRecipients = factory.deployTopUpAllowedRecipients(
            _trustedCaller,
            _allowedRecipientsRegistry,
            _token,
            finance,
            easyTrack
        );

        assert(topUpAllowedRecipients.token() == _token);
        assert(topUpAllowedRecipients.finance() == finance);
        assert(topUpAllowedRecipients.easyTrack() == easyTrack);
        assert(topUpAllowedRecipients.trustedCaller() == _trustedCaller);
        assert(
            address(topUpAllowedRecipients.allowedRecipientsRegistry()) ==
                _allowedRecipientsRegistry
        );
    }

    function deployAddAllowedRecipient(address _trustedCaller, address _allowedRecipientsRegistry)
        public
        returns (IAddAllowedRecipient addAllowedRecipient)
    {
        addAllowedRecipient = factory.deployAddAllowedRecipient(
            _trustedCaller,
            _allowedRecipientsRegistry
        );

        assert(addAllowedRecipient.trustedCaller() == _trustedCaller);
        assert(
            address(addAllowedRecipient.allowedRecipientsRegistry()) == _allowedRecipientsRegistry
        );
    }

    function deployRemoveAllowedRecipient(
        address _trustedCaller,
        address _allowedRecipientsRegistry
    ) public returns (IRemoveAllowedRecipient removeAllowedRecipient) {
        removeAllowedRecipient = factory.deployRemoveAllowedRecipient(
            _trustedCaller,
            _allowedRecipientsRegistry
        );

        assert(removeAllowedRecipient.trustedCaller() == _trustedCaller);
        assert(
            address(removeAllowedRecipient.allowedRecipientsRegistry()) ==
                _allowedRecipientsRegistry
        );
    }

    function deployFullSetup(
        address _trustedCaller,
        uint256 _limit,
        uint256 _periodDurationMonths,
        address[] memory _tokens,
        address[] memory _recipients,
        string[] memory _titles,
        uint256 _spentAmount
    )
        public
    {
        IAllowedRecipientsRegistry allowedRecipientsRegistry = deployAllowedRecipientsRegistry(
            _limit,
            _periodDurationMonths,
            _tokens,
            _recipients,
            _titles,
            _spentAmount,
            true
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            deployTopUpAllowedRecipients(
                _trustedCaller,
                address(allowedRecipientsRegistry),
                _tokens[i]
            );
        }

        deployAddAllowedRecipient(
            _trustedCaller,
            address(allowedRecipientsRegistry)
        );

        deployRemoveAllowedRecipient(
            _trustedCaller,
            address(allowedRecipientsRegistry)
        );
    }

    function deploySingleRecipientTopUpOnlySetup(
        address _recipient,
        string memory _title,
        address[] memory _tokens,
        uint256 _limit,
        uint256 _periodDurationMonths,
        uint256 _spentAmount
    )
        public
    {
        address[] memory recipients = new address[](1);
        recipients[0] = _recipient;

        string[] memory titles = new string[](1);
        titles[0] = _title;

        IAllowedRecipientsRegistry allowedRecipientsRegistry = deployAllowedRecipientsRegistry(
            _limit,
            _periodDurationMonths,
            _tokens,
            recipients,
            titles,
            _spentAmount,
            false
        );

        for (uint256 i = 0; i < _tokens.length; i++) {
            deployTopUpAllowedRecipients(
                _recipient,
                address(allowedRecipientsRegistry),
                _tokens[i]
            );
        }
    }
}