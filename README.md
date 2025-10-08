# 🏛️ Transparent Government Budget Tracker

> 📊 Real-time transparency for public fund allocation and spending through blockchain technology

## 🌟 Overview

The Transparent Government Budget Tracker is a Clarity smart contract that enables citizens to monitor how public funds are allocated and spent in real-time. Government departments can create budget proposals, set milestones with deliverables, and track spending progress while citizens can vote on budget proposals and monitor execution.

## ✨ Key Features

- 💰 **Budget Creation & Approval**: Government departments can propose budgets with detailed descriptions
- 🗳️ **Citizen Voting**: Public can vote on proposed budgets before approval
- 🎯 **Milestone Tracking**: Break down budgets into trackable milestones with specific deliverables
- 📈 **Real-time Monitoring**: Track spending progress and budget efficiency in real-time
- 🔍 **Full Transparency**: All budget data and spending history is publicly accessible
- 📊 **Analytics**: Built-in efficiency metrics and spending rate calculations

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Clarity smart contracts

### Installation

```bash
clarinet new budget-tracker
cd budget-tracker
```

Copy the contract code into `contracts/Transparent-Government-Budget-Tracker.clar`

### Testing

```bash
clarinet console
```

## 📋 Usage Guide

### 🏗️ Creating a Budget

Government officials can create budget proposals:

```clarity
(contract-call? .Transparent-Government-Budget-Tracker create-budget 
  "Road Infrastructure 2024" 
  "Repair and maintenance of city roads and bridges" 
  u1000000 
  "Transportation")
```

### ✅ Approving Budgets

Contract owner can approve proposed budgets:

```clarity
(contract-call? .Transparent-Government-Budget-Tracker approve-budget u1)
```

### 🎯 Creating Milestones

Add trackable milestones to approved budgets:

```clarity
(contract-call? .Transparent-Government-Budget-Tracker create-milestone 
  u1 
  "Phase 1: Main Street Repairs" 
  "Complete repairs on Main Street from 1st to 10th Avenue" 
  u250000 
  u1000 
  "Repaired road surface with quality certification")
```

### 🗳️ Citizen Voting

Citizens can vote on proposed budgets:

```clarity
(contract-call? .Transparent-Government-Budget-Tracker vote-on-budget u1 true)
```

### ✅ Completing Milestones

Mark milestones as completed when deliverables are met:

```clarity
(contract-call? .Transparent-Government-Budget-Tracker complete-milestone u1)
```

## 🔍 Monitoring & Analytics

### View Budget Details
```clarity
(contract-call? .Transparent-Government-Budget-Tracker get-budget u1)
```

### Check Spending Efficiency
```clarity
(contract-call? .Transparent-Government-Budget-Tracker get-budget-efficiency u1)
```

### Overall Spending Rate
```clarity
(contract-call? .Transparent-Government-Budget-Tracker get-overall-spending-rate)
```

### View Voting Results
```clarity
(contract-call? .Transparent-Government-Budget-Tracker get-budget-votes u1)
```

## 📊 Contract Functions

### Public Functions
- `create-budget` - Create new budget proposal
- `approve-budget` - Approve proposed budget (owner only)
- `create-milestone` - Add milestone to approved budget
- `complete-milestone` - Mark milestone as completed (owner only)
- `vote-on-budget` - Vote on budget proposal

### Read-Only Functions
- `get-budget` - Retrieve budget details
- `get-milestone` - Get milestone information
- `get-budget-milestones` - List all milestones for a budget
- `get-budget-votes` - View voting results
- `get-citizen-vote` - Check individual citizen's vote
- `get-total-allocated` - Total allocated funds
- `get-total-spent` - Total spent funds
- `get-budget-efficiency` - Calculate budget efficiency percentage
- `get-overall-spending-rate` - Overall spending rate across all budgets

## 🏗️ Data Structure

### Budget Status Flow
1. **Proposed** → Citizens can vote
2. **Approved** → Milestones can be created
3. **In Progress** → Milestones being completed
4. **Completed** → All milestones finished

### Milestone Status Flow
1. **Pending** → Awaiting completion
2. **Completed** → Deliverable achieved, funds released

## 🔐 Security Features

- Owner-only functions for budget approval and milestone completion
- Validation checks for fund allocation limits
- One vote per citizen per budget
- Immutable spending history

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## 📄 License

This project is open source and available under the MIT License.

---

*Built with ❤️ for government transparency and citizen empowerment*
```

**Git Commit Message:**
```
feat: implement transparent government budget tracker MVP with citizen voting and milestone tracking
