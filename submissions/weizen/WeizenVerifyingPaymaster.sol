// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/*
 * WeizenVerifyingPaymaster — ERC-4337 v0.7 VerifyingPaymaster (Oracle School Workshop-06)
 *
 * Sponsored-gas paymaster: an off-chain "verifyingSigner" signs (userOpHash, validUntil, validAfter).
 * If the signature checks out, the paymaster pays gas (in ETH, from its EntryPoint deposit) for the user.
 *
 * v0.7 facts this contract is faithful to (verified vs eth-infinitism/account-abstraction):
 *   - EntryPoint v0.7 canonical = 0x0000000071727De22E5E9d8BAf0edAc6f37da032 (same address every chain)
 *   - validatePaymasterUserOp(PackedUserOperation, bytes32 userOpHash, uint256 maxCost)
 *       returns (bytes context, uint256 validationData)
 *   - postOp(PostOpMode mode, bytes context, uint256 actualGasCost, uint256 actualUserOpFeePerGas)
 *       -> in v0.7, postOpReverted is NEVER passed; postOp is called once (v0.6 called it twice).
 *
 * Minimal/standalone: structs+interface inlined so it compiles + deploys on a bare anvil chain
 * without pulling the full account-abstraction lib. For the real shared chain, point at the
 * canonical EntryPoint and deploy with the eth-infinitism BasePaymaster as the base.
 */

struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}

enum PostOpMode {
    opSucceeded,
    opReverted,
    postOpReverted // v0.7: never passed in a call to postOp()
}

interface IEntryPointMinimal {
    function depositTo(address account) external payable;
    function balanceOf(address account) external view returns (uint256);
    function withdrawTo(address payable to, uint256 amount) external;
}

contract WeizenVerifyingPaymaster {
    address public immutable entryPoint;
    address public owner;
    address public verifyingSigner;

    // packed-validationData helpers (ERC-4337): sigFailed flag in the low bit
    uint256 internal constant SIG_VALIDATION_FAILED = 1;
    uint256 internal constant SIG_VALIDATION_SUCCESS = 0;

    event Sponsored(address indexed sender, uint256 maxCost);
    event GasSettled(address indexed sender, uint256 actualGasCost);

    error NotEntryPoint();
    error NotOwner();

    modifier onlyEntryPoint() {
        if (msg.sender != entryPoint) revert NotEntryPoint();
        _;
    }
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(address _entryPoint, address _verifyingSigner) {
        entryPoint = _entryPoint;
        owner = msg.sender;
        verifyingSigner = _verifyingSigner;
    }

    /// off-chain signer signs keccak256(userOpHash, validUntil, validAfter, chainid, address(this))
    function getHash(bytes32 userOpHash, uint48 validUntil, uint48 validAfter)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(userOpHash, validUntil, validAfter, block.chainid, address(this))
        );
    }

    /// ERC-4337 v0.7 entry: called by EntryPoint during the validation phase.
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 maxCost
    ) external onlyEntryPoint returns (bytes memory context, uint256 validationData) {
        // paymasterAndData layout (v0.7):
        // [0:20]=paymaster [20:36]=verificationGasLimit [36:52]=postOpGasLimit [52:58]=validUntil [58:64]=validAfter [64:]=signature
        bytes calldata pnd = userOp.paymasterAndData;
        uint48 validUntil = uint48(bytes6(pnd[52:58]));
        uint48 validAfter = uint48(bytes6(pnd[58:64]));
        bytes calldata sig = pnd[64:];

        bytes32 h = _toEthSignedMessageHash(getHash(userOpHash, validUntil, validAfter));
        bool ok = _recover(h, sig) == verifyingSigner;

        emit Sponsored(userOp.sender, maxCost);
        context = abi.encode(userOp.sender);
        // pack (authorizer=0, validUntil, validAfter); low bit = sig fail
        uint256 sigFlag = ok ? SIG_VALIDATION_SUCCESS : SIG_VALIDATION_FAILED;
        validationData = sigFlag | (uint256(validUntil) << 160) | (uint256(validAfter) << 208);
    }

    /// ERC-4337 v0.7: called once after execution (v0.6 called twice).
    function postOp(
        PostOpMode mode,
        bytes calldata context,
        uint256 actualGasCost,
        uint256 actualUserOpFeePerGas
    ) external onlyEntryPoint {
        mode; // sponsored model: nothing to claw back from the user
        actualUserOpFeePerGas;
        address sender = abi.decode(context, (address));
        emit GasSettled(sender, actualGasCost);
    }

    // --- EntryPoint stake/deposit plumbing ---
    function deposit() external payable {
        IEntryPointMinimal(entryPoint).depositTo{value: msg.value}(address(this));
    }

    function getDeposit() external view returns (uint256) {
        return IEntryPointMinimal(entryPoint).balanceOf(address(this));
    }

    function setVerifyingSigner(address s) external onlyOwner {
        verifyingSigner = s;
    }

    // --- minimal ECDSA (no external lib) ---
    function _toEthSignedMessageHash(bytes32 hash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
    }

    function _recover(bytes32 hash, bytes calldata sig) internal pure returns (address) {
        if (sig.length != 65) return address(0);
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := calldataload(sig.offset)
            s := calldataload(add(sig.offset, 32))
            v := byte(0, calldataload(add(sig.offset, 64)))
        }
        if (v < 27) v += 27;
        return ecrecover(hash, v, r, s);
    }
}
