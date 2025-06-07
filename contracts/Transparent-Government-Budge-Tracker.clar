(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_BUDGET_NOT_FOUND (err u102))
(define-constant ERR_MILESTONE_NOT_FOUND (err u103))
(define-constant ERR_INVALID_STATUS (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_MILESTONE_NOT_COMPLETED (err u106))

(define-data-var next-budget-id uint u1)
(define-data-var next-milestone-id uint u1)
(define-data-var total-allocated uint u0)
(define-data-var total-spent uint u0)

(define-map budgets
  { budget-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 500),
    total-amount: uint,
    allocated-amount: uint,
    spent-amount: uint,
    department: (string-ascii 50),
    created-by: principal,
    created-at: uint,
    status: (string-ascii 20)
  }
)

(define-map milestones
  { milestone-id: uint }
  {
    budget-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    amount: uint,
    target-date: uint,
    completion-date: (optional uint),
    status: (string-ascii 20),
    deliverable: (string-ascii 200),
    created-at: uint
  }
)

(define-map budget-milestones
  { budget-id: uint }
  { milestone-ids: (list 50 uint) }
)

(define-map citizen-votes
  { citizen: principal, budget-id: uint }
  { vote: bool, voted-at: uint }
)

(define-map budget-votes
  { budget-id: uint }
  { yes-votes: uint, no-votes: uint, total-votes: uint }
)

(define-public (create-budget (title (string-ascii 100)) (description (string-ascii 500)) (total-amount uint) (department (string-ascii 50)))
  (let
    (
      (budget-id (var-get next-budget-id))
    )
    (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
    (map-set budgets
      { budget-id: budget-id }
      {
        title: title,
        description: description,
        total-amount: total-amount,
        allocated-amount: u0,
        spent-amount: u0,
        department: department,
        created-by: tx-sender,
        created-at: stacks-block-height,
        status: "proposed"
      }
    )
    (map-set budget-votes
      { budget-id: budget-id }
      { yes-votes: u0, no-votes: u0, total-votes: u0 }
    )
    (var-set next-budget-id (+ budget-id u1))
    (ok budget-id)
  )
)

(define-public (approve-budget (budget-id uint))
  (let
    (
      (budget (unwrap! (map-get? budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set budgets
      { budget-id: budget-id }
      (merge budget { status: "approved" })
    )
    (var-set total-allocated (+ (var-get total-allocated) (get total-amount budget)))
    (ok true)
  )
)

(define-public (create-milestone (budget-id uint) (title (string-ascii 100)) (description (string-ascii 300)) (amount uint) (target-date uint) (deliverable (string-ascii 200)))
  (let
    (
      (milestone-id (var-get next-milestone-id))
      (budget (unwrap! (map-get? budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (current-milestones (default-to { milestone-ids: (list) } (map-get? budget-milestones { budget-id: budget-id })))
    )
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq (get status budget) "approved") ERR_INVALID_STATUS)
    (asserts! (<= (+ (get allocated-amount budget) amount) (get total-amount budget)) ERR_INSUFFICIENT_FUNDS)
    
    (map-set milestones
      { milestone-id: milestone-id }
      {
        budget-id: budget-id,
        title: title,
        description: description,
        amount: amount,
        target-date: target-date,
        completion-date: none,
        status: "pending",
        deliverable: deliverable,
        created-at: stacks-block-height
      }
    )
    
    (map-set budget-milestones
      { budget-id: budget-id }
      { milestone-ids: (unwrap! (as-max-len? (append (get milestone-ids current-milestones) milestone-id) u50) ERR_INVALID_AMOUNT) }
    )
    
    (map-set budgets
      { budget-id: budget-id }
      (merge budget { allocated-amount: (+ (get allocated-amount budget) amount) })
    )
    
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

(define-public (complete-milestone (milestone-id uint))
  (let
    (
      (milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (budget (unwrap! (map-get? budgets { budget-id: (get budget-id milestone) }) ERR_BUDGET_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status milestone) "pending") ERR_INVALID_STATUS)
    
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone { 
        status: "completed",
        completion-date: (some stacks-block-height)
      })
    )
    
    (map-set budgets
      { budget-id: (get budget-id milestone) }
      (merge budget { spent-amount: (+ (get spent-amount budget) (get amount milestone)) })
    )
    
    (var-set total-spent (+ (var-get total-spent) (get amount milestone)))
    (ok true)
  )
)

(define-public (vote-on-budget (budget-id uint) (vote bool))
  (let
    (
      (budget (unwrap! (map-get? budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (current-votes (unwrap! (map-get? budget-votes { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (existing-vote (map-get? citizen-votes { citizen: tx-sender, budget-id: budget-id }))
    )
    (asserts! (is-eq (get status budget) "proposed") ERR_INVALID_STATUS)
    (asserts! (is-none existing-vote) ERR_UNAUTHORIZED)
    
    (map-set citizen-votes
      { citizen: tx-sender, budget-id: budget-id }
      { vote: vote, voted-at: stacks-block-height }
    )
    
    (if vote
      (map-set budget-votes
        { budget-id: budget-id }
        {
          yes-votes: (+ (get yes-votes current-votes) u1),
          no-votes: (get no-votes current-votes),
          total-votes: (+ (get total-votes current-votes) u1)
        }
      )
      (map-set budget-votes
        { budget-id: budget-id }
        {
          yes-votes: (get yes-votes current-votes),
          no-votes: (+ (get no-votes current-votes) u1),
          total-votes: (+ (get total-votes current-votes) u1)
        }
      )
    )
    (ok true)
  )
)

(define-read-only (get-budget (budget-id uint))
  (map-get? budgets { budget-id: budget-id })
)

(define-read-only (get-milestone (milestone-id uint))
  (map-get? milestones { milestone-id: milestone-id })
)

(define-read-only (get-budget-milestones (budget-id uint))
  (map-get? budget-milestones { budget-id: budget-id })
)

(define-read-only (get-budget-votes (budget-id uint))
  (map-get? budget-votes { budget-id: budget-id })
)

(define-read-only (get-citizen-vote (citizen principal) (budget-id uint))
  (map-get? citizen-votes { citizen: citizen, budget-id: budget-id })
)

(define-read-only (get-total-allocated)
  (var-get total-allocated)
)

(define-read-only (get-total-spent)
  (var-get total-spent)
)

(define-read-only (get-budget-efficiency (budget-id uint))
  (let
    (
      (budget (unwrap! (map-get? budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
    )
    (if (> (get allocated-amount budget) u0)
      (ok (/ (* (get spent-amount budget) u100) (get allocated-amount budget)))
      (ok u0)
    )
  )
)

(define-read-only (get-overall-spending-rate)
  (if (> (var-get total-allocated) u0)
    (/ (* (var-get total-spent) u100) (var-get total-allocated))
    u0
  )
)

(define-read-only (get-next-budget-id)
  (var-get next-budget-id)
)

(define-read-only (get-next-milestone-id)
  (var-get next-milestone-id)
)
