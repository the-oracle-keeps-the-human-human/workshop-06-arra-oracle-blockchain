// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";
import {OrzVerifyingPaymaster} from "../contracts/OrzVerifyingPaymaster.sol";

/// @notice Deploys OrzVerifyingPaymaster to Sepolia + deposits + stakes.
/// @dev    `forge script script/Deploy.s.sol --rpc-url sepolia --broadcast --verify`
///         Env vars required:
///           DEPLOYER_PK  — funded EOA private key (signs the deploy + deposit tx)
///           SIGNER_ADDR  — off-chain signer EOA address baked into the paymaster
///           ENTRYPOINT   — defaults to v0.7 canonical (0x...71727De22E5E9d8B...)
///           INITIAL_DEPOSIT_WEI — defaults to 0.05 ether
///           INITIAL_STAKE_WEI   — defaults to 0.01 ether
///           UNSTAKE_DELAY_SEC   — defaults to 86400 (1 day)
contract Deploy is Script {
    address public constant ENTRYPOINT_V07 = 0x0000000071727De22E5E9d8BAf0edAc6f37da032;

    function run() external returns (OrzVerifyingPaymaster paymaster) {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        address signerAddr = vm.envAddress("SIGNER_ADDR");
        address entryPointAddr = vm.envOr("ENTRYPOINT", ENTRYPOINT_V07);
        uint256 depositWei = vm.envOr("INITIAL_DEPOSIT_WEI", uint256(0.05 ether));
        uint256 stakeWei = vm.envOr("INITIAL_STAKE_WEI", uint256(0.01 ether));
        uint32 unstakeDelay = uint32(vm.envOr("UNSTAKE_DELAY_SEC", uint256(86_400)));

        vm.startBroadcast(deployerPk);

        IEntryPoint entryPoint = IEntryPoint(entryPointAddr);
        paymaster = new OrzVerifyingPaymaster(entryPoint, signerAddr);

        // Deposit ETH so the paymaster can sponsor userOps.
        entryPoint.depositTo{value: depositWei}(address(paymaster));

        // Stake ETH so the paymaster has reputation in the bundler mempool.
        paymaster.addStake{value: stakeWei}(unstakeDelay);

        vm.stopBroadcast();

        console2.log("OrzVerifyingPaymaster:", address(paymaster));
        console2.log("EntryPoint:           ", address(entryPoint));
        console2.log("Signer:               ", signerAddr);
        console2.log("Deposit (wei):        ", depositWei);
        console2.log("Stake (wei):          ", stakeWei);
        console2.log("Unstake delay (sec):  ", unstakeDelay);
    }
}
