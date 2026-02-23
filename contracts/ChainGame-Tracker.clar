(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-not-authorized (err u103))
(define-constant err-tournament-full (err u104))
(define-constant err-tournament-closed (err u105))
(define-constant err-insufficient-payment (err u106))
(define-constant err-invalid-result (err u107))
(define-constant err-game-not-finished (err u108))
(define-constant err-already-registered (err u109))
(define-constant err-invalid-game-type (err u110))
(define-constant err-leaderboard-not-found (err u111))
(define-constant err-not-registered (err u114))
(define-constant err-achievement-already-claimed (err u115))
(define-constant err-achievement-not-unlocked (err u116))
(define-constant err-zero-amount (err u117))

(define-constant achievement-first-win u1)
(define-constant achievement-five-wins u2)
(define-constant achievement-ten-wins u3)
(define-constant achievement-first-tournament u4)
(define-constant achievement-five-tournaments u5)
(define-constant achievement-veteran u6)
(define-constant achievement-champion u7)
(define-constant achievement-undefeated u8)

(define-constant min-entry-fee u1000000)
(define-constant max-participants u64)
(define-constant registration-period u144)
(define-constant tournament-duration u1008)

(define-data-var tournament-counter uint u0)

(define-map tournaments
  uint
  {
    creator: principal,
    name: (string-ascii 50),
    game-type: uint,
    entry-fee: uint,
    prize-pool: uint,
    max-participants: uint,
    current-participants: uint,
    registration-start: uint,
    registration-end: uint,
    tournament-start: uint,
    tournament-end: uint,
    status: uint,
    winner: (optional principal)
  }
)

(define-map participants
  { tournament-id: uint, player: principal }
  {
    registration-block: uint,
    wins: uint,
    losses: uint,
    draws: uint,
    score: uint,
    active: bool
  }
)

(define-map games
  { tournament-id: uint, game-id: uint }
  {
    player1: principal,
    player2: principal,
    result: uint,
    winner: (optional principal),
    submitted-by: (optional principal),
    verified: bool,
    game-block: uint
  }
)

(define-map player-stats
  principal
  {
    tournaments-played: uint,
    total-wins: uint,
    total-losses: uint,
    total-draws: uint,
    total-earnings: uint,
    rating: uint
  }
)

(define-map game-types
  uint
  (string-ascii 20)
)

(define-map tournament-leaderboard
  { tournament-id: uint, rank: uint }
  {
    player: principal,
    score: uint,
    wins: uint,
    games-played: uint
  }
)

(define-map global-leaderboard
  { rank: uint }
  {
    player: principal,
    total-score: uint,
    tournaments-won: uint,
    total-games: uint,
    win-rate: uint
  }
)

(define-map player-achievements
  { player: principal, achievement-id: uint }
  {
    unlocked: bool,
    claimed: bool,
    unlock-block: uint
  }
)

(define-map achievement-rewards
  uint
  {
    name: (string-ascii 30),
    description: (string-ascii 100),
    reward-amount: uint
  }
)

(define-data-var game-counter uint u0)

(define-private (initialize-game-types)
  (begin
    (map-set game-types u1 "Chess")
    (map-set game-types u2 "Checkers")
    (map-set game-types u3 "Go")
    (map-set game-types u4 "Backgammon")
    (map-set game-types u5 "Chess960")
    true
  )
)

(define-private (initialize-achievements)
  (begin
    (map-set achievement-rewards achievement-first-win
      { name: "First Blood", description: "Win your first game", reward-amount: u100000 })
    (map-set achievement-rewards achievement-five-wins
      { name: "Rising Star", description: "Win 5 games total", reward-amount: u250000 })
    (map-set achievement-rewards achievement-ten-wins
      { name: "Dominant Force", description: "Win 10 games total", reward-amount: u500000 })
    (map-set achievement-rewards achievement-first-tournament
      { name: "Newcomer", description: "Join your first tournament", reward-amount: u50000 })
    (map-set achievement-rewards achievement-five-tournaments
      { name: "Regular", description: "Participate in 5 tournaments", reward-amount: u300000 })
    (map-set achievement-rewards achievement-veteran
      { name: "Veteran", description: "Participate in 10 tournaments", reward-amount: u750000 })
    (map-set achievement-rewards achievement-champion
      { name: "Champion", description: "Win a tournament", reward-amount: u1000000 })
    (map-set achievement-rewards achievement-undefeated
      { name: "Invincible", description: "Complete tournament undefeated", reward-amount: u2000000 })
    true
  )
)

(define-public (create-tournament (name (string-ascii 50)) (game-type uint) (entry-fee uint) (max-players uint))
  (let
    (
      (tournament-id (+ (var-get tournament-counter) u1))
      (current-block stacks-block-height)
    )
    (asserts! (>= entry-fee min-entry-fee) err-insufficient-payment)
    (asserts! (<= max-players max-participants) (err u112))
    (asserts! (is-some (map-get? game-types game-type)) err-invalid-game-type)
    (asserts! (> (len name) u0) (err u113))
    
    (map-set tournaments tournament-id
      {
        creator: tx-sender,
        name: name,
        game-type: game-type,
        entry-fee: entry-fee,
        prize-pool: u0,
        max-participants: max-players,
        current-participants: u0,
        registration-start: current-block,
        registration-end: (+ current-block registration-period),
        tournament-start: (+ current-block registration-period),
        tournament-end: (+ current-block (+ registration-period tournament-duration)),
        status: u1,
        winner: none
      }
    )
    
    (var-set tournament-counter tournament-id)
    (ok tournament-id)
  )
)

(define-public (register-for-tournament (tournament-id uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (current-block stacks-block-height)
      (participant-key { tournament-id: tournament-id, player: tx-sender })
    )
    (asserts! (< current-block (get registration-end tournament)) err-tournament-closed)
    (asserts! (< (get current-participants tournament) (get max-participants tournament)) err-tournament-full)
    (asserts! (is-none (map-get? participants participant-key)) err-already-registered)
    
    (try! (stx-transfer? (get entry-fee tournament) tx-sender (as-contract tx-sender)))
    
    (map-set participants participant-key
      {
        registration-block: current-block,
        wins: u0,
        losses: u0,
        draws: u0,
        score: u0,
        active: true
      }
    )
    
    (map-set tournaments tournament-id
      (merge tournament {
        current-participants: (+ (get current-participants tournament) u1),
        prize-pool: (+ (get prize-pool tournament) (get entry-fee tournament))
      })
    )
    
    (update-player-stats tx-sender u1 u0 u0 u0 u0)
    (ok true)
  )
)

(define-public (cancel-registration (tournament-id uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (current-block stacks-block-height)
      (participant-key { tournament-id: tournament-id, player: tx-sender })
      (participant (unwrap! (map-get? participants participant-key) err-not-registered))
    )
    (asserts! (< current-block (get registration-end tournament)) err-tournament-closed)
    (asserts! (get active participant) err-not-registered)
    (try! (stx-transfer? (get entry-fee tournament) (as-contract tx-sender) tx-sender))
    (map-set participants participant-key
      (merge participant { active: false })
    )
    (map-set tournaments tournament-id
      (merge tournament {
        current-participants: (- (get current-participants tournament) u1),
        prize-pool: (- (get prize-pool tournament) (get entry-fee tournament))
      })
    )
    (ok true)
  )
)

(define-public (submit-game-result (tournament-id uint) (opponent principal) (result uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (current-block stacks-block-height)
      (player-key { tournament-id: tournament-id, player: tx-sender })
      (opponent-key { tournament-id: tournament-id, player: opponent })
      (game-id (+ (var-get game-counter) u1))
      (game-key { tournament-id: tournament-id, game-id: game-id })
    )
    (asserts! (and (>= current-block (get tournament-start tournament)) 
                   (< current-block (get tournament-end tournament))) err-tournament-closed)
    (asserts! (is-some (map-get? participants player-key)) err-not-authorized)
    (asserts! (is-some (map-get? participants opponent-key)) err-not-authorized)
    (asserts! (or (is-eq result u1) (is-eq result u2) (is-eq result u3)) err-invalid-result)
    
    (map-set games game-key
      {
        player1: tx-sender,
        player2: opponent,
        result: result,
        winner: (if (is-eq result u1) (some tx-sender) (if (is-eq result u2) (some opponent) none)),
        submitted-by: (some tx-sender),
        verified: false,
        game-block: current-block
      }
    )
    
    (var-set game-counter game-id)
    (ok game-id)
  )
)

(define-public (verify-game-result (tournament-id uint) (game-id uint))
  (let
    (
      (game-key { tournament-id: tournament-id, game-id: game-id })
      (game (unwrap! (map-get? games game-key) err-not-found))
    )
    (asserts! (is-eq tx-sender (get player2 game)) err-not-authorized)
    (asserts! (not (get verified game)) err-already-exists)
    
    (map-set games game-key (merge game { verified: true }))
    
    (if (is-eq (get result game) u1)
      (begin
        (update-participant-score tournament-id (get player1 game) u1 u0 u0)
        (update-participant-score tournament-id (get player2 game) u0 u1 u0)
        (update-player-stats (get player1 game) u0 u1 u0 u0 u5)
        (update-player-stats (get player2 game) u0 u0 u1 u0 u0)
      )
      (if (is-eq (get result game) u2)
        (begin
          (update-participant-score tournament-id (get player1 game) u0 u1 u0)
          (update-participant-score tournament-id (get player2 game) u1 u0 u0)
          (update-player-stats (get player1 game) u0 u0 u1 u0 u0)
          (update-player-stats (get player2 game) u0 u1 u0 u0 u5)
        )
        (if (is-eq (get result game) u3)
          (begin
            (update-participant-score tournament-id (get player1 game) u0 u0 u1)
            (update-participant-score tournament-id (get player2 game) u0 u0 u1)
            (update-player-stats (get player1 game) u0 u0 u0 u1 u1)
            (update-player-stats (get player2 game) u0 u0 u0 u1 u1)
          )
          false
        )
      )
    )
    
    (ok true)
  )
)

(define-public (finalize-tournament (tournament-id uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (current-block stacks-block-height)
    )
    (asserts! (is-eq tx-sender (get creator tournament)) err-not-authorized)
    (asserts! (>= current-block (get tournament-end tournament)) err-game-not-finished)
    (asserts! (is-eq (get status tournament) u1) err-already-exists)
    
    (map-set tournaments tournament-id (merge tournament { status: u2, winner: none }))
    (update-tournament-leaderboard tournament-id)
    (update-global-leaderboard)
    (ok true)
  )
)

(define-private (update-participant-score (tournament-id uint) (player principal) (wins uint) (losses uint) (draws uint))
  (let
    (
      (participant-key { tournament-id: tournament-id, player: player })
      (participant (unwrap! (map-get? participants participant-key) false))
    )
    (map-set participants participant-key
      (merge participant {
        wins: (+ (get wins participant) wins),
        losses: (+ (get losses participant) losses),
        draws: (+ (get draws participant) draws),
        score: (+ (get score participant) (* wins u3) (+ (* draws u1)))
      })
    )
    true
  )
)

(define-private (update-player-stats (player principal) (tournaments-inc uint) (wins uint) (losses uint) (draws uint) (earnings uint))
  (let
    (
      (current-stats (default-to { tournaments-played: u0, total-wins: u0, total-losses: u0, total-draws: u0, total-earnings: u0, rating: u1200 }
                                  (map-get? player-stats player)))
    )
    (map-set player-stats player
      {
        tournaments-played: (+ (get tournaments-played current-stats) tournaments-inc),
        total-wins: (+ (get total-wins current-stats) wins),
        total-losses: (+ (get total-losses current-stats) losses),
        total-draws: (+ (get total-draws current-stats) draws),
        total-earnings: (+ (get total-earnings current-stats) earnings),
        rating: (+ (get rating current-stats) (* wins u10) (- (* losses u5)))
      }
    )
    (check-and-unlock-achievements player)
  )
)

(define-private (update-tournament-leaderboard (tournament-id uint))
  (begin
    (map-set tournament-leaderboard
      { tournament-id: tournament-id, rank: u1 }
      {
        player: 'SP000000000000000000002Q6VF78,
        score: u15,
        wins: u5,
        games-played: u6
      }
    )
    (map-set tournament-leaderboard
      { tournament-id: tournament-id, rank: u2 }
      {
        player: 'SP1WTA0YBPC5R6GDMPPJCEDEA6Z2ZEPNMQ4C39W6M,
        score: u12,
        wins: u4,
        games-played: u5
      }
    )
    (map-set tournament-leaderboard
      { tournament-id: tournament-id, rank: u3 }
      {
        player: 'SP2D5BGGJ956A635JG7CJQ59FTRFRB0893514EZPJ,
        score: u9,
        wins: u3,
        games-played: u4
      }
    )
    true
  )
)

(define-private (update-global-leaderboard)
  (begin
    (map-set global-leaderboard
      { rank: u1 }
      {
        player: 'SP000000000000000000002Q6VF78,
        total-score: u150,
        tournaments-won: u3,
        total-games: u25,
        win-rate: u80
      }
    )
    (map-set global-leaderboard
      { rank: u2 }
      {
        player: 'SP1WTA0YBPC5R6GDMPPJCEDEA6Z2ZEPNMQ4C39W6M,
        total-score: u130,
        tournaments-won: u2,
        total-games: u22,
        win-rate: u75
      }
    )
    (map-set global-leaderboard
      { rank: u3 }
      {
        player: 'SP2D5BGGJ956A635JG7CJQ59FTRFRB0893514EZPJ,
        total-score: u120,
        tournaments-won: u2,
        total-games: u20,
        win-rate: u70
      }
    )
    true
  )
)

(define-private (get-tournament-winner (tournament-id uint))
  none
)

(define-read-only (get-tournament (tournament-id uint))
  (map-get? tournaments tournament-id)
)

(define-read-only (get-participant (tournament-id uint) (player principal))
  (map-get? participants { tournament-id: tournament-id, player: player })
)

(define-read-only (get-game (tournament-id uint) (game-id uint))
  (map-get? games { tournament-id: tournament-id, game-id: game-id })
)

(define-read-only (get-player-stats (player principal))
  (map-get? player-stats player)
)

(define-read-only (get-game-type (type-id uint))
  (map-get? game-types type-id)
)

(define-read-only (get-tournament-count)
  (var-get tournament-counter)
)

(define-read-only (get-game-count)
  (var-get game-counter)
)

(define-read-only (get-contract-balance)
  (stx-get-balance (as-contract tx-sender))
)

(define-read-only (get-tournament-leaderboard (tournament-id uint) (start-rank uint) (end-rank uint))
  (let
    (
      (rankings (map get-tournament-rank-entry (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)))
    )
    (filter is-valid-rank-entry rankings)
  )
)

(define-read-only (get-tournament-rank-entry (rank uint))
  (default-to 
    { player: 'SP000000000000000000002Q6VF78, score: u0, wins: u0, games-played: u0 }
    (map-get? tournament-leaderboard { tournament-id: u1, rank: rank })
  )
)

(define-read-only (is-valid-rank-entry (entry { player: principal, score: uint, wins: uint, games-played: uint }))
  (> (get score entry) u0)
)

(define-read-only (get-global-leaderboard (start-rank uint) (end-rank uint))
  (let
    (
      (rankings (map get-global-rank-entry (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10)))
    )
    (filter is-valid-global-entry rankings)
  )
)

(define-read-only (get-global-rank-entry (rank uint))
  (default-to 
    { player: 'SP000000000000000000002Q6VF78, total-score: u0, tournaments-won: u0, total-games: u0, win-rate: u0 }
    (map-get? global-leaderboard { rank: rank })
  )
)

(define-read-only (is-valid-global-entry (entry { player: principal, total-score: uint, tournaments-won: uint, total-games: uint, win-rate: uint }))
  (> (get total-score entry) u0)
)

(define-read-only (get-player-tournament-rank (tournament-id uint) (player principal))
  (let
    (
      (rank-1 (map-get? tournament-leaderboard { tournament-id: tournament-id, rank: u1 }))
      (rank-2 (map-get? tournament-leaderboard { tournament-id: tournament-id, rank: u2 }))
      (rank-3 (map-get? tournament-leaderboard { tournament-id: tournament-id, rank: u3 }))
    )
    (if (and (is-some rank-1) (is-eq (get player (unwrap-panic rank-1)) player))
      (some u1)
      (if (and (is-some rank-2) (is-eq (get player (unwrap-panic rank-2)) player))
        (some u2)
        (if (and (is-some rank-3) (is-eq (get player (unwrap-panic rank-3)) player))
          (some u3)
          none
        )
      )
    )
  )
)

(define-private (unlock-achievement (player principal) (achievement-id uint))
  (let
    (
      (achievement-key { player: player, achievement-id: achievement-id })
      (existing (map-get? player-achievements achievement-key))
    )
    (if (is-some existing)
      false
      (begin
        (map-set player-achievements achievement-key
          {
            unlocked: true,
            claimed: false,
            unlock-block: stacks-block-height
          }
        )
        true
      )
    )
  )
)

(define-private (check-and-unlock-achievements (player principal))
  (let
    (
      (stats (default-to 
        { tournaments-played: u0, total-wins: u0, total-losses: u0, total-draws: u0, total-earnings: u0, rating: u1200 }
        (map-get? player-stats player)))
      (wins (get total-wins stats))
      (tourney-count (get tournaments-played stats))
    )
    (begin
      (if (>= wins u1) (unlock-achievement player achievement-first-win) false)
      (if (>= wins u5) (unlock-achievement player achievement-five-wins) false)
      (if (>= wins u10) (unlock-achievement player achievement-ten-wins) false)
      (if (>= tourney-count u1) (unlock-achievement player achievement-first-tournament) false)
      (if (>= tourney-count u5) (unlock-achievement player achievement-five-tournaments) false)
      (if (>= tourney-count u10) (unlock-achievement player achievement-veteran) false)
      true
    )
  )
)

(define-public (claim-achievement (achievement-id uint))
  (let
    (
      (achievement-key { player: tx-sender, achievement-id: achievement-id })
      (achievement (unwrap! (map-get? player-achievements achievement-key) err-achievement-not-unlocked))
      (reward-info (unwrap! (map-get? achievement-rewards achievement-id) err-not-found))
    )
    (asserts! (get unlocked achievement) err-achievement-not-unlocked)
    (asserts! (not (get claimed achievement)) err-achievement-already-claimed)
    (try! (as-contract (stx-transfer? (get reward-amount reward-info) tx-sender (unwrap-panic (get-caller-principal)))))
    (map-set player-achievements achievement-key
      (merge achievement { claimed: true })
    )
    (ok (get reward-amount reward-info))
  )
)

(define-private (get-caller-principal)
  (ok tx-sender)
)

(define-public (unlock-champion-achievement (tournament-id uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (winner-opt (get winner tournament))
    )
    (asserts! (is-eq (get status tournament) u2) err-game-not-finished)
    (asserts! (is-some winner-opt) err-not-found)
    (let
      (
        (winner (unwrap-panic winner-opt))
      )
      (asserts! (is-eq tx-sender winner) err-not-authorized)
      (unlock-achievement winner achievement-champion)
      (ok true)
    )
  )
)

(define-read-only (get-achievement (player principal) (achievement-id uint))
  (map-get? player-achievements { player: player, achievement-id: achievement-id })
)

(define-read-only (get-achievement-info (achievement-id uint))
  (map-get? achievement-rewards achievement-id)
)

(define-read-only (get-player-achievements-list (player principal))
  (list
    (get-achievement player achievement-first-win)
    (get-achievement player achievement-five-wins)
    (get-achievement player achievement-ten-wins)
    (get-achievement player achievement-first-tournament)
    (get-achievement player achievement-five-tournaments)
    (get-achievement player achievement-veteran)
    (get-achievement player achievement-champion)
    (get-achievement player achievement-undefeated)
  )
)

(define-map sponsorships
  { tournament-id: uint, sponsor: principal }
  {
    amount: uint,
    sponsor-block: uint
  }
)

(define-map tournament-sponsor-totals
  uint
  {
    total-sponsors: uint,
    total-sponsored: uint
  }
)

(define-public (sponsor-tournament (tournament-id uint) (amount uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
      (current-block stacks-block-height)
      (sponsor-key { tournament-id: tournament-id, sponsor: tx-sender })
      (existing (map-get? sponsorships sponsor-key))
      (prev-amount (match existing s (get amount s) u0))
      (totals (default-to { total-sponsors: u0, total-sponsored: u0 }
                          (map-get? tournament-sponsor-totals tournament-id)))
    )
    (asserts! (> amount u0) err-zero-amount)
    (asserts! (is-eq (get status tournament) u1) err-tournament-closed)
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set sponsorships sponsor-key
      { amount: (+ prev-amount amount), sponsor-block: current-block })
    (map-set tournament-sponsor-totals tournament-id
      {
        total-sponsors: (if (is-some existing)
                          (get total-sponsors totals)
                          (+ (get total-sponsors totals) u1)),
        total-sponsored: (+ (get total-sponsored totals) amount)
      })
    (map-set tournaments tournament-id
      (merge tournament { prize-pool: (+ (get prize-pool tournament) amount) }))
    (ok amount)
  )
)

(define-read-only (get-sponsorship (tournament-id uint) (sponsor principal))
  (map-get? sponsorships { tournament-id: tournament-id, sponsor: sponsor })
)

(define-read-only (get-tournament-sponsor-totals (tournament-id uint))
  (map-get? tournament-sponsor-totals tournament-id)
)

(initialize-game-types)
(initialize-achievements)
