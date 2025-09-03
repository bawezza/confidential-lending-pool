// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint64, externalEuint64 } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

/// @title Confidential Lending Pool — Private Borrowing & Lending with FHEVM
/// @notice Deposits, borrows and repayments are encrypted (euint64).
/// @dev Fail-closed logic prevents revealing whether a borrow exceeded limits.
contract ConfidentialLending is SepoliaConfig {
    address public owner;

    // Basis points (1e4 = 100%)
    uint256 public constant BPS = 10_000;

    // Collateral factor: user can borrow up to 50% of encrypted collateral
    uint256 public constant COLLATERAL_FACTOR_BPS = 5_000; // 50%

    // Simple demo interest rate applied per accrueInterest(user) call
    uint256 public interestRateBps = 100; // 1% per call

    // Encrypted balances
    mapping(address => euint64) private _deposits;
    mapping(address => euint64) private _debts;

    event Deposited(address indexed user);          // amounts are private
    event Borrowed(address indexed user);
    event Repaid(address indexed user);
    event InterestAccrued(address indexed user);
    event InterestRateUpdated(uint256 newRateBps);

    error NotOwner();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /* ------------------------------ Views --------------------------------- */

    function getDeposit(address user) external view returns (euint64) {
        return _deposits[user];
    }

    function getDebt(address user) external view returns (euint64) {
        return _dets(user);
    }

    // internal helper (avoids stack-depth warnings)
    function _dets(address user) internal view returns (euint64) {
        return _debts[user];
    }

    /* ----------------------------- Mutations ------------------------------- */

    /// @notice Encrypted deposit top-up by msg.sender.
    function deposit(externalEuint64 encryptedAmount, bytes calldata inputProof) external {
        euint64 amt = FHE.fromExternal(encryptedAmount, inputProof);
        _deposits[msg.sender] = FHE.add(_deposits[msg.sender], amt);

        // grant read permissions
        FHE.allowThis(_deposits[msg.sender]);
        FHE.allow(_deposits[msg.sender], msg.sender);

        emit Deposited(msg.sender);
    }

    /// @notice Encrypted borrow request. Executed amount is 0 if over the limit.
    function borrow(externalEuint64 encryptedAmount, bytes calldata inputProof) external returns (euint64) {
        euint64 req = FHE.fromExternal(encryptedAmount, inputProof);

        // newDebt = currentDebt + req
        euint64 newDebt = FHE.add(_debts[msg.sender], req);

        // Check: collateral*CF >= newDebt*BPS   (all encrypted)
        euint64 left  = FHE.mul(_deposits[msg.sender], FHE.asEuint64(uint64(COLLATERAL_FACTOR_BPS)));
        euint64 right = FHE.mul(newDebt,               FHE.asEuint64(uint64(BPS)));

        // canBorrow ? req : 0   (fail-closed)
        euint64 executed = FHE.select(FHE.ge(left, right), req, FHE.asEuint64(0));

        // update debt with executed (0 if not allowed)
        _debts[msg.sender] = FHE.add(_debts[msg.sender], executed);

        FHE.allowThis(_debts[msg.sender]);
        FHE.allow(_debts[msg.sender], msg.sender);

        emit Borrowed(msg.sender);
        return executed;
    }

    /// @notice Encrypted repayment. Repays up to outstanding debt.
    function repay(externalEuint64 encryptedAmount, bytes calldata inputProof) external returns (euint64) {
        euint64 amt = FHE.fromExternal(encryptedAmount, inputProof);

        // executed = min(amt, debt)
        euint64 executed = FHE.min(amt, _debts[msg.sender]);
        _debts[msg.sender] = FHE.sub(_debts[msg.sender], executed);

        FHE.allowThis(_debts[msg.sender]);
        FHE.allow(_debts[msg.sender], msg.sender);

        emit Repaid(msg.sender);
        return executed;
    }

    /// @notice Apply interest to a user's encrypted debt: debt += debt * rate / BPS.
    function accrueInterest(address user) external onlyOwner {
        euint64 d = _debts[user];
        euint64 interest = FHE.div(
            FHE.mul(d, FHE.asEuint64(uint64(interestRateBps))),
            FHE.asEuint64(uint64(BPS))
        );
        _debts[user] = FHE.add(d, interest);

        FHE.allowThis(_debts[user]);
        FHE.allow(_debts[user], user);

        emit InterestAccrued(user);
    }

    /// @notice Owner can update interest rate (bps).
    function setInterestRateBps(uint256 newRateBps) external onlyOwner {
        require(newRateBps <= 2000, "rate too high"); // cap 20% per call (demo safety)
        interestRateBps = newRateBps;
        emit InterestRateUpdated(newRateBps);
    }
}
