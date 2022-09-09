import constants

from brownie.network import chain
from brownie import EasyTrack, EVMScriptExecutor, accounts, reverts

from eth_abi import encode_single
from utils.evm_script import encode_call_script, encode_calldata

from utils.config import get_network_name

from utils.lido import create_voting, execute_voting, addresses

from utils.test_helpers import (
    assert_single_event,
    assert_event_exists,
    access_control_revert_message,
    SET_LIMIT_PARAMETERS_ROLE,
)

from utils.deployment import (
    add_evm_script_allowed_recipients_factories
)


#def create_permission(contract, method):
#    return contract.address + getattr(contract, method).signature[2:]


# #######################################
#   The following TODOs are test plan   #
# #######################################

# TODO: just motion creation for the new factory

# TODO: test motion ended and enacted in the same period

# TODO: test motion ended in the same and enacted in the next period

# TODO: test motion ended and enacted in the next period

# TODO: test motion enacted in after-the-next period

# TODO: test attempt to exceed the limit for a specific recipient
#       test attempt to exceed the period limit
#       test the limit is cumulative for all allowed recipients

# TODO: test max number of the allowed recipients

# TODO: test attempt to remove not allowed recipient

# TODO: test attempt to add an already allowed recipient

# TODO: ?? the limits are checked at the time of enactment

# TODO: ?? the limits are checked at the time of motion creation

# TODO: test LimitsChecker functions
#       - incorrect period durations (e. g. 7 months)
#       - cover all functions

# TODO: changing limit and/or period duration while motion is on the go

# TODO: checking that createMotion also reverts if limit exceeds

# TODO: cover all the events
#       - AllowedRecipientAdded
#       - AllowedRecipientRemoved
#       - LimitsParametersChanged
#       - FundsSpent

# TODO: cover all error messages

# TODO: add test_xxx for each factory like tests in tests/evm_script_factories


MOTION_DURATION_SECS: int = 48 * 60 * 60


def test_add_remove_recipient(entire_allowed_recipients_setup, accounts, stranger):
    (
        easy_track,
        _,  # evm_script_executor,
        allowed_recipients_registry,
        _,  # top_up_allowed_recipients,
        add_allowed_recipient,
        remove_allowed_recipient,
    ) = entire_allowed_recipients_setup

    recipient = accounts[8]
    recipient_title = "New Allowed Recipient"

    trusted_address = accounts[7]

    add_allowed_recipient_calldata = encode_calldata(
        "(address,string)", [recipient.address, recipient_title]
    )

    tx = easy_track.createMotion(
        add_allowed_recipient, add_allowed_recipient_calldata, {"from": trusted_address}
    )

    chain.sleep(constants.MIN_MOTION_DURATION + 100)

    tx = easy_track.enactMotion(
        easy_track.getMotions()[0][0],
        tx.events["MotionCreated"]["_evmScriptCallData"],
        {"from": stranger},
    )
    assert_event_exists(
        tx,
        "AllowedRecipientAdded",
        {"_allowedRecipient": recipient, "_title": recipient_title},
    )

    assert len(easy_track.getMotions()) == 0
    assert allowed_recipients_registry.getAllowedRecipients() == [recipient]

    assert allowed_recipients_registry.isAllowedRecipient(recipient)
    assert not allowed_recipients_registry.isAllowedRecipient(stranger)

    # create new motion to remove a allowed recipient
    tx = easy_track.createMotion(
        remove_allowed_recipient,
        encode_single("(address)", [recipient.address]),
        {"from": trusted_address},
    )
    motion_calldata = tx.events["MotionCreated"]["_evmScriptCallData"]

    chain.sleep(constants.MIN_MOTION_DURATION + 100)

    tx = easy_track.enactMotion(
        easy_track.getMotions()[0][0],
        motion_calldata,
        {"from": stranger},
    )
    assert len(allowed_recipients_registry.getAllowedRecipients()) == 0
    assert_event_exists(
        tx,
        "AllowedRecipientRemoved",
        {"_allowedRecipient": recipient},
    )
    assert not allowed_recipients_registry.isAllowedRecipient(recipient)


def test_motion_created_and_enacted_in_same_period(
    entire_allowed_recipients_setup_with_two_recipients,
):
    (
        easy_track,
        evm_script_executor,
        allowed_recipients_registry,
        top_up_allowed_recipients,
        add_allowed_recipient,
        remove_allowed_recipient,
        recipient1,
        recipient2,
    ) = entire_allowed_recipients_setup_with_two_recipients
    assert False, "TODO"


def test_limits_checker_access_restriction(
    owner, lego_program, stranger, LimitsCheckerWrapper, easy_track, bokkyPooBahsDateTimeContract
):
    manager = lego_program

    limits_checker = owner.deploy(
        LimitsCheckerWrapper, easy_track, [manager], bokkyPooBahsDateTimeContract
    )

    with reverts(access_control_revert_message(stranger, SET_LIMIT_PARAMETERS_ROLE)):
        limits_checker.setLimitParameters(123, 1, {"from": stranger})

    with reverts(access_control_revert_message(owner, SET_LIMIT_PARAMETERS_ROLE)):
        limits_checker.setLimitParameters(123, 1, {"from": owner})

    with reverts("CALLER_IS_FORBIDDEN"):
        limits_checker.updateSpendableBalance(123, {"from": stranger})

    with reverts("CALLER_IS_FORBIDDEN"):
        limits_checker.updateSpendableBalance(123, {"from": manager})


def test_limits_checker_incorrect_period_duration(
    owner, lego_program, LimitsCheckerWrapper, easy_track, bokkyPooBahsDateTimeContract
):
    pass
    manager = lego_program
    limits_checker = owner.deploy(
        LimitsCheckerWrapper, easy_track, [manager], bokkyPooBahsDateTimeContract
    )

    period_limit = 10**18
    for duration in [0, 4, 5, 7, 8, 9, 10, 11, 13, 14, 100500]:
        with reverts("WRONG_PERIOD_DURATION"):
            limits_checker.setLimitParameters(period_limit, duration, {"from": manager})


def test_limits_checker(
    owner, lego_program, stranger, LimitsCheckerWrapper, easy_track, bokkyPooBahsDateTimeContract
):
    # TODO: don't fix specific months, otherwise the test won't work next month
    SEPTEMBER_1 = 1661990400  # Sep 01 2022 00:00:00 GMT+0000
    OCTOBER_1 = 1664582400  # Oct 01 2022 00:00:00 GMT+0000

    manager = lego_program
    script_executor = easy_track.evmScriptExecutor()

    limits_checker = owner.deploy(
        LimitsCheckerWrapper, easy_track, [manager], bokkyPooBahsDateTimeContract
    )
    assert limits_checker.getLimitParameters() == (0, 0)

    # TODO fix: call reverts due to call of _getPeriodStartFromTimestamp when period duration is zero
    # assert limits_checker.getCurrentPeriodState() == (0, 0, 0, 0)

    assert limits_checker.currentSpendableBalance() == 0
    assert limits_checker.isUnderSpendableBalance(0)

    period_limit, period_duration = 3 * 10**18, 1

    tx = limits_checker.setLimitParameters(period_limit, period_duration, {"from": manager})
    assert_single_event(
        tx,
        "LimitsParametersChanged",
        {"_limit": period_limit, "_periodDurationMonth": period_duration},
    )
    assert limits_checker.getLimitParameters() == (period_limit, period_duration)

    spending = 1 * 10**18
    spendable = period_limit - spending
    tx = limits_checker.updateSpendableBalance(spending, {"from": script_executor})
    assert limits_checker.getCurrentPeriodState() == (spending, spendable, SEPTEMBER_1, OCTOBER_1)
    assert_single_event(
        tx,
        "FundsSpent",
        {
            "_alreadySpentAmount": spending,
            "_spendableAmount": spendable,
            "_periodStartTimestamp": SEPTEMBER_1,
            "_periodEndTimestamp": OCTOBER_1,
        },
    )


def test_allowed_recipients_happy_path(
    stranger,
    agent,
    voting,
    finance,
    ldo,
    calls_script,
    acl,
    AllowedRecipientsRegistry,
    TopUpAllowedRecipients,
    AddAllowedRecipient,
    RemoveAllowedRecipient,
    bokkyPooBahsDateTimeContract,
):
    deployer = accounts[0]
    allowed_recipient = accounts[5]
    allowed_recipient_title = "New Allowed Recipient"
    trusted_address = accounts[7]

    # deploy easy track
    easy_track = deployer.deploy(
        EasyTrack,
        ldo,
        deployer,
        constants.MIN_MOTION_DURATION,
        constants.MAX_MOTIONS_LIMIT,
        constants.DEFAULT_OBJECTIONS_THRESHOLD,
    )

    # deploy evm script executor
    evm_script_executor = deployer.deploy(EVMScriptExecutor, calls_script, easy_track)
    evm_script_executor.transferOwnership(voting, {"from": deployer})
    assert evm_script_executor.owner() == voting

    # set EVM script executor in easy track
    easy_track.setEVMScriptExecutor(evm_script_executor, {"from": deployer})

    # deploy AllowedRecipientsRegistry
    allowed_recipients_registry = deployer.deploy(
        AllowedRecipientsRegistry,
        voting,
        [voting, evm_script_executor],
        [voting, evm_script_executor],
        [voting, evm_script_executor],
        easy_track,
        bokkyPooBahsDateTimeContract,
    )
    # deploy TopUpAllowedRecipients EVM script factory
    top_up_allowed_recipients = deployer.deploy(
        TopUpAllowedRecipients, trusted_address, allowed_recipients_registry, finance, ldo
    )
    # deploy AddAllowedRecipient EVM script factory
    add_allowed_recipient = deployer.deploy(
        AddAllowedRecipient, trusted_address, allowed_recipients_registry
    )
    # deploy RemoveAllowedRecipient EVM script factory
    remove_allowed_recipient = deployer.deploy(
        RemoveAllowedRecipient, trusted_address, allowed_recipients_registry
    )

    add_evm_script_allowed_recipients_factories(
        easy_track,
        add_allowed_recipient,
        remove_allowed_recipient,
        top_up_allowed_recipients,
        allowed_recipients_registry,
        finance,
        {"from": deployer}
    )

    # create voting to grant permissions to EVM script executor to create new payments
    add_create_payments_permissions_voting_id, _ = create_voting(
        evm_script=encode_call_script(
            [
                (
                    acl.address,
                    acl.grantPermission.encode_input(
                        evm_script_executor,
                        finance,
                        finance.CREATE_PAYMENTS_ROLE(),
                    ),
                ),
            ]
        ),
        description="Grant permissions to EVMScriptExecutor to make payments",
        network=get_network_name(),
        tx_params={"from": agent},
    )

    # execute voting to add permissions to EVM script executor to create payments
    execute_voting(add_create_payments_permissions_voting_id, get_network_name())

    add_allowed_recipient_calldata = encode_calldata(
        "(address,string)", [allowed_recipient.address, allowed_recipient_title]
    )

    # create new motion to add a allowed recipient
    expected_evm_script = add_allowed_recipient.createEVMScript(
        trusted_address, add_allowed_recipient_calldata
    )

    tx = easy_track.createMotion(
        add_allowed_recipient, add_allowed_recipient_calldata, {"from": trusted_address}
    )

    motions = easy_track.getMotions()
    assert len(motions) == 1

    chain.sleep(48 * 60 * 60 + 100)

    easy_track.enactMotion(
        motions[0][0],
        tx.events["MotionCreated"]["_evmScriptCallData"],
        {"from": stranger},
    )
    assert len(easy_track.getMotions()) == 0

    allowed_recipients = allowed_recipients_registry.getAllowedRecipients()
    assert len(allowed_recipients) == 1
    assert allowed_recipients[0] == allowed_recipient

    Jul1 = 1656633600  # Fri Jul 01 2022 00:00:00 GMT+0000
    Aug1 = 1659312000  # Mon Aug 01 2022 00:00:00 GMT+0000
    Sep1 = 1661990400  # Thu Sep 01 2022 00:00:00 GMT+0000
    Okt1 = 1664582400  # Sat Oct 01 2022 00:00:00 GMT+0000
    Jan12022 = 1640995200
    Jan12023 = 1672531200

    # set limit parameters
    limit = 20e18
    spent = 0
    periodDurationMonth = 12  # month
    periodStart = Jan12022
    periodEnd = Jan12023

    # create voting to set limit parameters

    set_limit_parameters_voting_id, _ = create_voting(
        evm_script=encode_call_script(
            [
                (
                    allowed_recipients_registry.address,
                    allowed_recipients_registry.setLimitParameters.encode_input(
                        limit,
                        periodDurationMonth,
                    ),
                ),
            ]
        ),
        description="Set limit parameters",
        network=get_network_name(),
        tx_params={"from": agent},
    )

    # execute voting to add permissions to EVM script executor to create payments
    execute_voting(set_limit_parameters_voting_id, get_network_name())

    assert allowed_recipients_registry.getLimitParameters()[0] == limit
    assert allowed_recipients_registry.getLimitParameters()[1] == periodDurationMonth

    currentPeriodState = allowed_recipients_registry.getCurrentPeriodState()
    assert currentPeriodState[0] == spent
    assert currentPeriodState[1] == limit - spent
    assert currentPeriodState[2] == periodStart
    assert currentPeriodState[3] == periodEnd

    # create new motion to top up allowed address
    _evmScriptCallData1 = encode_single(
        "(address[],uint256[])",
        [[allowed_recipient.address, allowed_recipient.address], [int(5e18), int(7e18)]],
    )
    tx1 = easy_track.createMotion(
        top_up_allowed_recipients,
        _evmScriptCallData1,
        {"from": trusted_address},
    )
    assert len(easy_track.getMotions()) == 1

    chain.sleep(60)

    _evmScriptCallData2 = encode_single(
        "(address[],uint256[])",
        [[allowed_recipient.address, allowed_recipient.address], [int(5e18), int(7e18)]],
    )
    tx2 = easy_track.createMotion(
        top_up_allowed_recipients,
        _evmScriptCallData2,
        {"from": trusted_address},
    )
    assert len(easy_track.getMotions()) == 2

    chain.sleep(48 * 60 * 60 + 1)

    currentPeriodState = allowed_recipients_registry.getCurrentPeriodState()
    assert currentPeriodState[0] == spent
    assert currentPeriodState[1] == limit - spent
    assert currentPeriodState[2] == periodStart
    assert currentPeriodState[3] == periodEnd

    assert ldo.balanceOf(allowed_recipient) == 0
    motions = easy_track.getMotions()
    easy_track.enactMotion(
        motions[0][0],
        tx1.events["MotionCreated"]["_evmScriptCallData"],
        {"from": stranger},
    )
    spent += 5e18 + 7e18

    currentPeriodState = allowed_recipients_registry.getCurrentPeriodState()
    assert currentPeriodState[0] == spent
    assert currentPeriodState[1] == limit - spent
    assert currentPeriodState[2] == periodStart
    assert currentPeriodState[3] == periodEnd

    assert len(easy_track.getMotions()) == 1
    assert ldo.balanceOf(allowed_recipient) == spent

    chain.sleep(60)

    motions = easy_track.getMotions()
    assert len(motions) == 1
    with reverts("SUM_EXCEEDS_LIMIT"):
        easy_track.enactMotion(
            motions[0][0],
            tx2.events["MotionCreated"]["_evmScriptCallData"],
            {"from": stranger},
        )

    currentPeriodState = allowed_recipients_registry.getCurrentPeriodState()
    assert currentPeriodState[0] == spent
    assert currentPeriodState[1] == limit - spent
    assert currentPeriodState[2] == periodStart
    assert currentPeriodState[3] == periodEnd
    assert len(easy_track.getMotions()) == 1
    assert ldo.balanceOf(allowed_recipient) == spent

    easy_track.cancelMotion(motions[0][0], {"from": trusted_address})

    currentPeriodState = allowed_recipients_registry.getCurrentPeriodState()
    assert currentPeriodState[0] == spent
    assert currentPeriodState[1] == limit - spent
    assert currentPeriodState[2] == periodStart
    assert currentPeriodState[3] == periodEnd
    assert len(easy_track.getMotions()) == 0
    assert ldo.balanceOf(allowed_recipient) == spent

    # create new motion to remove a allowed recipient
    tx = easy_track.createMotion(
        remove_allowed_recipient,
        encode_single("(address)", [allowed_recipient.address]),
        {"from": trusted_address},
    )

    chain.sleep(constants.MIN_MOTION_DURATION + 100)

    easy_track.enactMotion(
        easy_track.getMotions()[0][0],
        tx.events["MotionCreated"]["_evmScriptCallData"],
        {"from": stranger},
    )
    assert len(easy_track.getMotions()) == 0
    assert len(allowed_recipients_registry.getAllowedRecipients()) == 0
