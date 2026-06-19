// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {UserOperationLib} from "account-abstraction/core/UserOperationLib.sol";
import {_packValidationData} from "account-abstraction/core/Helpers.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// @title  OrzVerifyingPaymaster
/// @notice ERC-4337 v0.7 paymaster — off-chain `signer` authorises userOps by signing
///         (userOpHash, validUntil, validAfter). Paymaster sponsors gas in ETH from
///         its EntryPoint deposit; allowlist policy lives off-chain in `api/server.ts`.
/// @dev    Layout of `paymasterAndData` (after the 20-byte paymaster addr + 32-byte
///         gas limits the EntryPoint strips for us via `paymasterDataOffset`):
///           [validUntil(uint48)][validAfter(uint48)][signature(65)]
///         Total tail: 6 + 6 + 65 = 77 bytes.
contract OrzVerifyingPaymaster is BasePaymaster {
    using UserOperationLib for PackedUserOperation;
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    /// @notice Off-chain signer address (EOA the API holds the PK for).
    address public signer;

    /// @notice Domain tag mixed into the signed digest to prevent cross-chain replay.
    string public constant DOMAIN_TAG = "OrzVerifyingPaymaster.v1";

    uint256 private constant SIG_TAIL_LEN = 77;

    event SignerUpdated(address indexed previousSigner, address indexed newSigner);

    error InvalidPaymasterDataLength(uint256 got);
    error InvalidSignature();

    constructor(IEntryPoint _entryPoint, address _signer) BasePaymaster(_entryPoint) {
        require(_signer != address(0), "signer=0");
        signer = _signer;
        emit SignerUpdated(address(0), _signer);
    }

    /// @notice Owner-only signer rotation. Lets the API rotate keys without redeploying.
    function setSigner(address newSigner) external onlyOwner {
        require(newSigner != address(0), "signer=0");
        emit SignerUpdated(signer, newSigner);
        signer = newSigner;
    }

    /// @notice Compute the digest the off-chain signer must sign.
    /// @dev    Bound to: chainId + paymaster addr + userOpHash + validity window + sender.
    ///         Sender is included so policy upstream can't be tricked by a userOpHash
    ///         that was signed for one sender then replayed for another.
    function getHash(
        PackedUserOperation calldata userOp,
        uint48 validUntil,
        uint48 validAfter
    ) public view returns (bytes32) {
        return keccak256(
            abi.encode(
                DOMAIN_TAG,
                block.chainid,
                address(this),
                userOp.getSender(),
                userOp.nonce,
                keccak256(userOp.callData),
                userOp.accountGasLimits,
                userOp.preVerificationGas,
                userOp.gasFees,
                validUntil,
                validAfter
            )
        );
    }

    /// @inheritdoc BasePaymaster
    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /* userOpHash */,
        uint256 /* maxCost */
    ) internal view override returns (bytes memory context, uint256 validationData) {
        bytes calldata data = userOp.paymasterAndData;
        // BasePaymaster has already verified data.length >= PAYMASTER_DATA_OFFSET (52).
        bytes calldata tail = data[UserOperationLib.PAYMASTER_DATA_OFFSET:];
        if (tail.length != SIG_TAIL_LEN) revert InvalidPaymasterDataLength(tail.length);

        uint48 validUntil = uint48(bytes6(tail[0:6]));
        uint48 validAfter = uint48(bytes6(tail[6:12]));
        bytes calldata sig = tail[12:77];

        bytes32 digest = getHash(userOp, validUntil, validAfter).toEthSignedMessageHash();
        address recovered = digest.recover(sig);
        bool sigFailed = (recovered != signer);

        // EntryPoint v0.7 packed validation data: [aggregator(20)][validUntil(48)][validAfter(48)]
        // aggregator = address(1) signals failure, address(0) signals success.
        validationData = _packValidationData(sigFailed, validUntil, validAfter);
        // We don't need post-op state in v1, so return empty context.
        context = "";
    }

    // No-op _postOp: we sponsor pure ETH gas, no token settlement.
}
