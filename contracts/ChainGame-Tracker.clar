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

(define-public (create-tournament (name (string-ascii 50)) (game-type uint) (entry-fee uint) (max-players uint))
  (let
    (
      (tournament-id (+ (var-get tournament-counter) u1))
      (current-block stacks-block-height)
    )
    (asserts! (>= entry-fee min-entry-fee) err-insufficient-payment)
    (asserts! (<= max-players max-participants) (err u111))
    (asserts! (is-some (map-get? game-types game-type)) err-invalid-game-type)
    (asserts! (> (len name) u0) (err u112))
    
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

(initialize-game-types)
