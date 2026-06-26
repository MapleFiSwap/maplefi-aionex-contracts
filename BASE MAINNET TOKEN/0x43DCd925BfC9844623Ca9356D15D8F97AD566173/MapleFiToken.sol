// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts@5.0.0/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts@5.0.0/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Capped} from "@openzeppelin/contracts@5.0.0/token/ERC20/extensions/ERC20Capped.sol";
import {ERC20Pausable} from "@openzeppelin/contracts@5.0.0/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts@5.0.0/token/ERC20/extensions/ERC20Permit.sol";
import {AccessControlDefaultAdminRules} from "@openzeppelin/contracts@5.0.0/access/extensions/AccessControlDefaultAdminRules.sol";
import {SafeERC20} from "@openzeppelin/contracts@5.0.0/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts@5.0.0/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts@5.0.0/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts@5.0.0/utils/ReentrancyGuard.sol";

/**
 * @title MapleFiToken
 * @notice Fixed-supply MPFI token for deployment on Base.
 *
 * Security properties:
 * - The complete 1,000,000,000 MPFI supply is minted once to `treasury`.
 * - No minting function exists after deployment.
 * - Transfers and burns can be globally paused by PAUSER_ROLE.
 * - Accidental ERC20/native assets can be recovered by RESCUER_ROLE.
 * - DEFAULT_ADMIN_ROLE uses OpenZeppelin's delayed, two-step transfer process.
 * - Every current and future default-admin delay is restricted to 1-30 days.
 *
 * Production dependency:
 * - OpenZeppelin Contracts package version 5.0.0 exactly (not a floating range).
 */
contract MapleFiToken is
    ERC20Burnable,
    ERC20Capped,
    ERC20Pausable,
    ERC20Permit,
    AccessControlDefaultAdminRules,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;
    using Address for address payable;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RESCUER_ROLE = keccak256("RESCUER_ROLE");

    uint256 public constant MAX_SUPPLY = 1_000_000_000 ether;
    uint48 public constant MIN_ADMIN_TRANSFER_DELAY = 1 days;
    uint48 public constant MAX_ADMIN_TRANSFER_DELAY = 30 days;

    event RescueERC20(
        address indexed token,
        address indexed to,
        uint256 amount
    );
    event RescueNative(address indexed to, uint256 amount);

    error ZeroAddress();
    error ZeroAmount();
    error InvalidAdminTransferDelay();

    /**
     * @param treasury Address receiving the complete fixed token supply.
     * @param initialAdmin Initial DEFAULT_ADMIN_ROLE holder. Use the admin multisig.
     * @param initialPauser Initial PAUSER_ROLE holder. Use the emergency multisig.
     * @param initialRescuer Initial RESCUER_ROLE holder. Use the operations multisig.
     * @param adminTransferDelay Delay for accepting a default-admin transfer,
     *        restricted to 1-30 days.
     */
    constructor(
        address treasury,
        address initialAdmin,
        address initialPauser,
        address initialRescuer,
        uint48 adminTransferDelay
    )
        ERC20("MapleFi", "MPFI")
        ERC20Permit("MapleFi")
        ERC20Capped(MAX_SUPPLY)
        AccessControlDefaultAdminRules(adminTransferDelay, initialAdmin)
    {
        if (
            treasury == address(0) ||
            initialAdmin == address(0) ||
            initialPauser == address(0) ||
            initialRescuer == address(0)
        ) {
            revert ZeroAddress();
        }

        if (
            adminTransferDelay < MIN_ADMIN_TRANSFER_DELAY ||
            adminTransferDelay > MAX_ADMIN_TRANSFER_DELAY
        ) {
            revert InvalidAdminTransferDelay();
        }

        _grantRole(PAUSER_ROLE, initialPauser);
        _grantRole(RESCUER_ROLE, initialRescuer);

        _mint(treasury, MAX_SUPPLY);
    }

    /**
     * @notice Pauses all MPFI transfers, transferFrom operations, minting and burns.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Restores MPFI transfers and burns.
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Recovers an ERC20 token held by this contract.
     * @dev This cannot move tokens from arbitrary holders or from the treasury.
     */
    function rescueERC20(
        address token,
        address to,
        uint256 amount
    ) external onlyRole(RESCUER_ROLE) nonReentrant {
        if (token == address(0) || to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        IERC20(token).safeTransfer(to, amount);

        emit RescueERC20(token, to, amount);
    }

    /**
     * @notice Recovers native currency held by this contract.
     */
    function rescueNative(
        address payable to,
        uint256 amount
    ) external onlyRole(RESCUER_ROLE) nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();

        to.sendValue(amount);

        emit RescueNative(to, amount);
    }

    /**
     * @notice Allows this contract to receive native currency sent without calldata.
     */
    receive() external payable {}

    /**
     * @dev Resolves ERC20Capped and ERC20Pausable's shared `_update` override.
     */
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Capped, ERC20Pausable) {
        super._update(from, to, value);
    }

    /**
     * @dev Enforces the same 1-30 day bounds for every post-deployment delay change.
     * Without this override, the inherited public delay setter accepts any uint48.
     */
    function _changeDefaultAdminDelay(
        uint48 newDelay
    ) internal override {
        if (
            newDelay < MIN_ADMIN_TRANSFER_DELAY ||
            newDelay > MAX_ADMIN_TRANSFER_DELAY
        ) {
            revert InvalidAdminTransferDelay();
        }

        super._changeDefaultAdminDelay(newDelay);
    }
}