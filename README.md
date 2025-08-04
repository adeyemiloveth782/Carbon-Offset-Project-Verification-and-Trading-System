# Carbon Offset Project Verification and Trading System

A comprehensive smart contract system built on Stacks blockchain for verifying and trading carbon offset projects. This system ensures the integrity of carbon credits through rigorous verification processes.

## System Overview

The system consists of five interconnected smart contracts that handle different aspects of carbon offset verification and trading:

### 1. Carbon Sequestration Measurement Contract
- Quantifies CO2 removal from atmosphere
- Supports reforestation, afforestation, and soil carbon projects
- Tracks measurement data and methodologies
- Validates measurement accuracy

### 2. Additionality Verification Contract
- Ensures projects wouldn't occur without carbon financing
- Implements baseline scenario analysis
- Tracks project dependencies and funding sources
- Prevents double-counting of natural projects

### 3. Permanence Monitoring Contract
- Tracks long-term carbon storage
- Monitors for potential reversals
- Implements buffer pools for risk management
- Provides early warning systems

### 4. Leakage Prevention Contract
- Prevents increased emissions elsewhere
- Monitors project boundaries and spillover effects
- Tracks regional emission patterns
- Implements leakage coefficients

### 5. Carbon Credit Issuance and Trading Contract
- Creates verified carbon credits
- Facilitates buying and selling
- Manages credit ownership and transfers
- Implements marketplace functionality

## Key Features

- **Comprehensive Verification**: Multi-stage verification process ensuring credit quality
- **Transparency**: All verification data stored on-chain
- **Traceability**: Complete audit trail from project to credit retirement
- **Risk Management**: Buffer pools and monitoring systems
- **Marketplace Integration**: Built-in trading functionality

## Contract Architecture

Each contract operates independently while maintaining data consistency through shared data structures and validation rules. The system prevents double-spending, ensures additionality, and maintains long-term monitoring capabilities.

## Getting Started

### Prerequisites
- Clarinet CLI
- Node.js 18+
- Stacks wallet for testing

### Installation

\`\`\`bash
git clone <repository-url>
cd carbon-offset-system
npm install
clarinet check
\`\`\`

### Testing

\`\`\`bash
npm test
\`\`\`

### Deployment

\`\`\`bash
clarinet deploy --testnet
\`\`\`

## Usage Examples

### Registering a Carbon Project

\`\`\`clarity
(contract-call? .carbon-sequestration register-project
"Reforestation Project Alpha"
"reforestation"
u1000
u50)
\`\`\`

### Verifying Additionality

\`\`\`clarity
(contract-call? .additionality-verification verify-additionality
u1
"baseline-scenario-data"
true)
\`\`\`

### Issuing Carbon Credits

\`\`\`clarity
(contract-call? .carbon-credit-trading issue-credits
u1
u950
'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KXW28M5JS8QE)
\`\`\`

## Data Structures

### Project Data
- Project ID, name, type
- Location coordinates
- Measurement methodology
- Verification status
- Timeline information

### Credit Data
- Credit ID and quantity
- Project reference
- Issuance date
- Current owner
- Retirement status

## Security Considerations

- Access control for critical functions
- Input validation and sanitization
- Overflow protection
- Reentrancy prevention
- Time-based validations

## Contributing

Please read our contributing guidelines and submit pull requests for any improvements.

## License

MIT License - see LICENSE file for details.
