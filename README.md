# 🎮 On-Chain Board Game Tournament Tracker 🏆

A decentralized tournament management system for board games built on the Stacks blockchain. Organize tamper-proof tournaments for chess, checkers, Go, and other strategy games with automatic entry fee collection and prize distribution.

## 🌟 Features

- **🎲 Multiple Game Types**: Support for Chess, Checkers, Go, Backgammon, and Chess960
- **💰 Automated Fee Collection**: Secure STX entry fee handling with smart contract escrow
- **🏅 Tournament Management**: Complete lifecycle from registration to prize distribution
- **📊 Player Statistics**: Track wins, losses, draws, ratings, and earnings
- **🔒 Tamper-Proof Results**: Blockchain-based game result verification
- **⚡ Automatic Payouts**: Smart contract handles prize distribution to winners

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone https://github.com/your-username/On-Chain-Board-Game-Tournament-Tracker.git
cd On-Chain-Board-Game-Tournament-Tracker
clarinet check
```

### 🎯 Basic Usage

#### 1. Create a Tournament

```clarity
(contract-call? .ChainGame-Tracker create-tournament 
  "Chess Masters 2024" 
  u1              ;; Chess game type
  u5000000        ;; Entry fee (5 STX)
  u16)            ;; Max 16 players
```

#### 2. Register for Tournament

```clarity
(contract-call? .ChainGame-Tracker register-for-tournament u1)
```

#### 3. Submit Game Results

```clarity
;; Submit result (u1 = win, u2 = loss, u3 = draw)
(contract-call? .ChainGame-Tracker submit-game-result 
  u1                           ;; Tournament ID
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 ;; Opponent
  u1)                          ;; Result: win
```

#### 4. Verify Results

```clarity
;; Opponent verifies the game result
(contract-call? .ChainGame-Tracker verify-game-result u1 u1)
```

#### 5. Finalize Tournament

```clarity
;; Tournament creator finalizes and distributes prizes
(contract-call? .ChainGame-Tracker finalize-tournament u1)
```

## 📋 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `create-tournament` | Create a new tournament with entry fee and game type |
| `register-for-tournament` | Join an existing tournament (pays entry fee) |
| `submit-game-result` | Submit the result of a played game |
| `verify-game-result` | Verify opponent's submitted result |
| `finalize-tournament` | End tournament and distribute prizes |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-tournament` | Get tournament details by ID |
| `get-participant` | Get participant stats for a tournament |
| `get-game` | Get specific game details |
| `get-player-stats` | Get overall player statistics |
| `get-game-type` | Get game type name by ID |
| `get-tournament-count` | Get total number of tournaments |
| `get-contract-balance` | Get contract's STX balance |

## 🎮 Supported Game Types

| ID | Game Type |
|----|----------|
| 1 | Chess |
| 2 | Checkers |
| 3 | Go |
| 4 | Backgammon |
| 5 | Chess960 |

## 🔧 Development

### Running Tests

```bash
npm install
npm test
```

### Local Development Console

```bash
clarinet console
```

Example console session:

```clarity
;; Deploy the contract
::deploy_contracts

;; Create a tournament
(contract-call? .ChainGame-Tracker create-tournament "Test Tournament" u1 u1000000 u4)

;; Check tournament details
(contract-call? .ChainGame-Tracker get-tournament u1)
```

## 📊 Tournament Lifecycle

```
📝 Create Tournament
     ↓
👥 Registration Period (144 blocks)
     ↓  
🎲 Tournament Period (1008 blocks)
     ↓
🏆 Finalization & Prize Distribution
```

## 💡 Game Result Codes

- `u1` - Player 1 wins
- `u2` - Player 2 wins  
- `u3` - Draw/Tie

## 🛡️ Security Features

- **Entry Fee Escrow**: Funds held securely by smart contract
- **Result Verification**: Both players must confirm game outcomes
- **Time-locked Periods**: Automated tournament phases
- **Access Controls**: Only authorized actions allowed

## 📈 Scoring System

- **Win**: 3 points
- **Draw**: 1 point
- **Loss**: 0 points

Player ratings are updated based on game outcomes with a simple ELO-style system.

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Clarinet](https://github.com/hirosystems/clarinet)
- Powered by [Stacks](https://stacks.co) blockchain
- Inspired by the global board game community 🌍

---

**Ready to organize your next tournament? Let's make board gaming more competitive and fair! 🎯🏅**

# On-Chain Board Game Tournament Tracker

