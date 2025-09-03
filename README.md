# Confidential Lending Pool — Private Borrowing and Lending with FHEVM

## 📑 Abstract
This project introduces a confidential lending pool powered by Zama’s FHEVM.  
It enables users to borrow and lend assets while keeping loan amounts, collateral, and repayment details encrypted.  
The system balances **privacy, verifiability, and DeFi composability**.  

## 🔐 Features
- **Confidential Loans** — encrypted principal, balances, and repayments.  
- **Private Collateral** — only verification logic knows collateral sufficiency, not its exact value.  
- **Composable with DeFi** — can integrate with DEXs, stablecoins, and yield protocols.  
- **EVM-Compatible** — deployable across Ethereum and L2 chains.  
- **Test Coverage** — lending, borrowing, repayment, and liquidation paths.  

## 📂 Project Structure
confidential-lending-pool/  
├── contracts/  
│   └── ConfidentialLendingPool.sol  
├── test/  
│   └── ConfidentialLendingPool.spec.ts  
├── hardhat.config.ts  
├── package.json  
├── .gitignore  
├── LICENSE  
└── README.md  

## 🚀 Getting Started
1. Install dependencies  
   npm install  

2. Compile contracts  
   npx hardhat compile  

3. Run the tests  
   npx hardhat test  

## 🔮 Use Cases
- Confidential overcollateralized loans.  
- DAO-managed lending pools with private borrower data.  
- Private credit markets with verifiable but hidden risk metrics.  

## 📝 License
This project is licensed under the MIT License.
