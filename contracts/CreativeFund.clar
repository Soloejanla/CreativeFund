;; CreativeFund: Decentralized Crowdfunding Platform for Creative Projects
;; This contract manages project funding, supporter contributions, and reward distributions

;; Error codes
(define-constant err-unauthorized (err u1))
(define-constant err-project-exists (err u2))
(define-constant err-project-not-found (err u3))
(define-constant err-insufficient-funds (err u4))
(define-constant err-funding-complete (err u5))
(define-constant err-transfer-failed (err u6))
(define-constant err-invalid-amount (err u7))
(define-constant err-invalid-string (err u8))

;; Data structures
(define-map projects
  { project-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 100),
    total-tokens: uint,
    remaining-tokens: uint,
    token-price: uint,
    total-rewards: uint,
    creator: principal
  }
)

(define-map backer-tokens
  { project-id: uint, backer: principal }
  { tokens: uint }
)

(define-map reward-distributions
  { distribution-id: uint }
  {
    project-id: uint,
    amount: uint,
    distribution-date: uint,
    completed: bool
  }
)

;; Variables
(define-data-var next-project-id uint u1)
(define-data-var next-distribution-id uint u1)
(define-data-var platform-fee-percent uint u2) ;; 2% platform fee
(define-data-var contract-owner principal tx-sender)

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? projects { project-id: project-id })
)

(define-read-only (get-tokens (project-id uint) (backer principal))
  (default-to { tokens: u0 }
    (map-get? backer-tokens { project-id: project-id, backer: backer })
  )
)

(define-read-only (get-distribution (distribution-id uint))
  (map-get? reward-distributions { distribution-id: distribution-id })
)

(define-read-only (calculate-token-value (project-id uint) (token-count uint))
  (let (
    (project (unwrap-panic (get-project project-id)))
    (token-price (get token-price project))
  )
    (* token-price token-count)
  )
)

;; Helper functions
(define-private (is-valid-string (value (string-ascii 100)))
  (> (len value) u0)
)

;; Public functions
(define-public (create-project (title (string-ascii 100)) (description (string-ascii 100)) (total-tokens uint) (token-price uint))
  (let (
    (project-id (var-get next-project-id))
    (caller tx-sender)
    (valid-title (is-valid-string title))
    (valid-description (is-valid-string description))
  )
    ;; Check that title is valid
    (asserts! valid-title err-invalid-string)
    
    ;; Check that description is valid
    (asserts! valid-description err-invalid-string)
    
    ;; Check that total tokens is greater than zero
    (asserts! (> total-tokens u0) err-invalid-amount)
    
    ;; Check that token price is greater than zero
    (asserts! (> token-price u0) err-invalid-amount)
    
    ;; Add the project to the map
    (map-set projects
      { project-id: project-id }
      {
        title: title,
        description: description,
        total-tokens: total-tokens,
        remaining-tokens: total-tokens,
        token-price: token-price,
        total-rewards: u0,
        creator: caller
      }
    )
    
    ;; Increment the project ID counter
    (var-set next-project-id (+ project-id u1))
    
    ;; Return the new project ID
    (ok project-id)
  )
)

(define-public (back-project (project-id uint) (token-count uint))
  (let (
    (project (unwrap-panic (get-project project-id)))
    (remaining-tokens (get remaining-tokens project))
    (token-price (get token-price project))
    (project-creator (get creator project))
    (total-cost (* token-price token-count))
    (caller tx-sender)
    (current-tokens (get tokens (get-tokens project-id caller)))
  )
    ;; Check that token count is greater than zero
    (asserts! (> token-count u0) err-invalid-amount)
    
    ;; Check that there are enough tokens available
    (asserts! (>= remaining-tokens token-count) err-funding-complete)
    
    ;; Transfer the STX from the backer to the project creator
    (asserts! (>= (stx-get-balance caller) total-cost) err-insufficient-funds)
    (try! (stx-transfer? total-cost caller project-creator))
    
    ;; Update the project's remaining tokens
    (map-set projects
      { project-id: project-id }
      (merge project { remaining-tokens: (- remaining-tokens token-count) })
    )
    
    ;; Update the backer's tokens
    (map-set backer-tokens
      { project-id: project-id, backer: caller }
      { tokens: (+ current-tokens token-count) }
    )
    
    (ok true)
  )
)

(define-public (add-rewards (project-id uint) (amount uint))
  (let (
    (project (unwrap-panic (get-project project-id)))
    (caller tx-sender)
    (project-creator (get creator project))
    (current-rewards (get total-rewards project))
    (validated-amount amount)
  )
    ;; Check that amount is greater than zero
    (asserts! (> validated-amount u0) err-invalid-amount)
    
    ;; Only the project creator can add rewards
    (asserts! (is-eq caller project-creator) err-unauthorized)
    
    ;; Transfer the STX from the caller to the contract
    (try! (stx-transfer? validated-amount caller (as-contract tx-sender)))
    
    ;; Update the project's total rewards
    (map-set projects
      { project-id: project-id }
      (merge project { total-rewards: (+ current-rewards validated-amount) })
    )
    
    ;; Create a new distribution
    (let (
      (distribution-id (var-get next-distribution-id))
    )
      (map-set reward-distributions
        { distribution-id: distribution-id }
        {
          project-id: project-id,
          amount: validated-amount,
          distribution-date: u0,
          completed: false
        }
      )
      
      ;; Increment the distribution ID counter
      (var-set next-distribution-id (+ distribution-id u1))
      
      (ok distribution-id)
    )
  )
)

(define-public (distribute-rewards (distribution-id uint))
  (let (
    (distribution (unwrap-panic (get-distribution distribution-id)))
    (project-id (get project-id distribution))
    (amount (get amount distribution))
    (completed (get completed distribution))
    (project (unwrap-panic (get-project project-id)))
    (total-tokens (get total-tokens project))
    (platform-fee (/ (* amount (var-get platform-fee-percent)) u100))
    (distributable-amount (- amount platform-fee))
  )
    ;; Check that the distribution hasn't already been completed
    (asserts! (not completed) err-unauthorized)
    
    ;; Mark the distribution as completed
    (map-set reward-distributions
      { distribution-id: distribution-id }
      (merge distribution { completed: true })
    )
    
    (ok true)
  )
)

(define-public (claim-rewards (project-id uint) (distribution-id uint))
  (let (
    (distribution (unwrap-panic (get-distribution distribution-id)))
    (distribution-project-id (get project-id distribution))
    (amount (get amount distribution))
    (completed (get completed distribution))
    (project (unwrap-panic (get-project project-id)))
    (total-tokens (get total-tokens project))
    (caller tx-sender)
    (backer-token-count (get tokens (get-tokens project-id caller)))
    (platform-fee (/ (* amount (var-get platform-fee-percent)) u100))
    (distributable-amount (- amount platform-fee))
    (backer-reward (/ (* distributable-amount backer-token-count) total-tokens))
  )
    ;; Check that the project IDs match
    (asserts! (is-eq project-id distribution-project-id) err-project-not-found)
    
    ;; Check that the backer has tokens
    (asserts! (> backer-token-count u0) err-unauthorized)
    
    ;; Check that the distribution is completed
    (asserts! completed err-unauthorized)
    
    ;; Transfer the backer's share of the rewards
    (try! (as-contract (stx-transfer? backer-reward tx-sender caller)))
    
    (ok backer-reward)
  )
)

(define-public (set-platform-fee (new-fee-percent uint))
  (begin
    ;; Only the contract owner can set the platform fee
    (asserts! (is-eq tx-sender (var-get contract-owner)) err-unauthorized)
    
    ;; Fee cannot be more than 10%
    (asserts! (<= new-fee-percent u10) err-invalid-amount)
    
    (var-set platform-fee-percent new-fee-percent)
    (ok true)
  )
)