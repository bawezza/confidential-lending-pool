# Confidential Lending Pool — Private Borrowing and Lending with FHEVM

Confidential Lending Pool is a privacy-preserving DeFi protocol built with Zama’s FHEVM. Users can deposit collateral, borrow, accrue interest, and repay — all with encrypted balances.

## ✨ Features
- Encrypted deposits and debts (`euint64`)
- 50% LTV enforced privately with fail-closed borrowing
- Per-user interest accrual (demo: 1% per call)
- Repayment uses encrypted `min(amount, debt)`
- Fully EVM-compatible with TypeScript tests

## 🛠 Quickstart
```bash
npm i
npx hardhat test
