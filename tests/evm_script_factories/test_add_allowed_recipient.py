from brownie import ZERO_ADDRESS, reverts
from eth_abi import encode_single

EVM_SCRIPT_CALL_DATA_TITLE = "TITLE"


def test_deploy(owner, AddAllowedRecipient, allowed_recipients_registry):
    "Must deploy contract with correct data"
    (registry, _, _, _, _, _) = allowed_recipients_registry
    contract = owner.deploy(AddAllowedRecipient, owner, registry)

    assert contract.trustedCaller() == owner
    assert contract.allowedRecipientsRegistry() == registry


def test_deploy_zero_trusted_caller(owner, AddAllowedRecipient, allowed_recipients_registry):
    "Must revert deploying a contract with zero trusted caller"
    (registry, _, _, _, _, _) = allowed_recipients_registry

    with reverts("TRUSTED_CALLER_IS_ZERO_ADDRESS"):
        owner.deploy(AddAllowedRecipient, ZERO_ADDRESS, registry)


def test_deploy_zero_allowed_recipient_registry(owner, AddAllowedRecipient):
    "Must deploy contract with zero allowed recipient registry"
    contract = owner.deploy(AddAllowedRecipient, owner, ZERO_ADDRESS)

    assert contract.allowedRecipientsRegistry() == ZERO_ADDRESS


def test_create_evm_script_is_permissionless(owner, stranger, add_allowed_recipients):
    call_data = create_calldata(owner.address)
    add_allowed_recipients.createEVMScript(owner, call_data, {"from": stranger})


def test_decode_evm_script_calldata_is_permissionless(stranger, add_allowed_recipients):
    call_data = create_calldata(stranger.address)
    add_allowed_recipients.decodeEVMScriptCallData(call_data, {"from": stranger})


def test_only_trusted_caller_can_be_creator(owner, stranger, add_allowed_recipients):
    call_data = create_calldata(owner.address)

    with reverts("CALLER_IS_FORBIDDEN"):
        add_allowed_recipients.createEVMScript(stranger, call_data, {"from": owner})

    add_allowed_recipients.createEVMScript(owner, call_data, {"from": owner})


def test_revert_create_evm_script_with_empty_calldata(owner, add_allowed_recipients):
    with reverts():
        add_allowed_recipients.createEVMScript(owner, "0x", {"from": owner})


def test_revert_create_evm_script_with_empty_recipient_address(owner, add_allowed_recipients):
    call_data = create_calldata(ZERO_ADDRESS)
    with reverts("RECIPIENT_ADDRESS_IS_ZERO_ADDRESS"):
        add_allowed_recipients.createEVMScript(owner, call_data, {"from": owner})


def test_decode_evm_script_calldata_correctly(owner, add_allowed_recipients):
    call_data = create_calldata(owner.address)

    (address, title) = add_allowed_recipients.decodeEVMScriptCallData(call_data)
    assert address == owner.address
    assert title == EVM_SCRIPT_CALL_DATA_TITLE


def create_calldata(recipient):
    return encode_single("(address,string)", [recipient, EVM_SCRIPT_CALL_DATA_TITLE])