(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_INVALID_AMOUNT (err u101))
(define-constant ERR_BUDGET_NOT_FOUND (err u102))
(define-constant ERR_MILESTONE_NOT_FOUND (err u103))
(define-constant ERR_INVALID_STATUS (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_MILESTONE_NOT_COMPLETED (err u106))
(define-constant ERR_AMENDMENT_NOT_FOUND (err u107))
(define-constant ERR_AMENDMENT_ALREADY_VOTED (err u108))
(define-constant ERR_AMENDMENT_NOT_PENDING (err u109))

(define-constant ERR_INVALID_RATING (err u110))
(define-constant ERR_BUDGET_NOT_COMPLETED (err u111))
(define-constant ERR_ALREADY_RATED (err u112))

(define-constant ERR_NOT_DELEGATED (err u113))
(define-constant ERR_DELEGATION_EXISTS (err u114))

(define-data-var next-delegation-id uint u1)

(define-data-var next-amendment-id uint u1)

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


(define-map budget-amendments
  { amendment-id: uint }
  {
    budget-id: uint,
    proposed-amount: uint,
    reason: (string-ascii 200),
    proposed-by: principal,
    created-at: uint,
    status: (string-ascii 20)
  }
)

(define-map amendment-votes
  { amendment-id: uint }
  { yes-votes: uint, no-votes: uint, total-votes: uint }
)

(define-map citizen-amendment-votes
  { citizen: principal, amendment-id: uint }
  { vote: bool, voted-at: uint }
)

(define-public (propose-budget-amendment (budget-id uint) (new-amount uint) (reason (string-ascii 200)))
  (let
    (
      (amendment-id (var-get next-amendment-id))
      (budget (unwrap! (map-get? budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
    )
    (asserts! (> new-amount u0) ERR_INVALID_AMOUNT)
    (asserts! (is-eq (get status budget) "approved") ERR_INVALID_STATUS)
    
    (map-set budget-amendments
      { amendment-id: amendment-id }
      {
        budget-id: budget-id,
        proposed-amount: new-amount,
        reason: reason,
        proposed-by: tx-sender,
        created-at: stacks-block-height,
        status: "pending"
      }
    )
    
    (map-set amendment-votes
      { amendment-id: amendment-id }
      { yes-votes: u0, no-votes: u0, total-votes: u0 }
    )
    
    (var-set next-amendment-id (+ amendment-id u1))
    (ok amendment-id)
  )
)

(define-public (vote-on-amendment (amendment-id uint) (vote bool))
  (let
    (
      (amendment (unwrap! (map-get? budget-amendments { amendment-id: amendment-id }) ERR_AMENDMENT_NOT_FOUND))
      (current-votes (unwrap! (map-get? amendment-votes { amendment-id: amendment-id }) ERR_AMENDMENT_NOT_FOUND))
      (existing-vote (map-get? citizen-amendment-votes { citizen: tx-sender, amendment-id: amendment-id }))
    )
    (asserts! (is-eq (get status amendment) "pending") ERR_AMENDMENT_NOT_PENDING)
    (asserts! (is-none existing-vote) ERR_AMENDMENT_ALREADY_VOTED)
    
    (map-set citizen-amendment-votes
      { citizen: tx-sender, amendment-id: amendment-id }
      { vote: vote, voted-at: stacks-block-height }
    )
    
    (map-set amendment-votes
      { amendment-id: amendment-id }
      (if vote
        { yes-votes: (+ (get yes-votes current-votes) u1), no-votes: (get no-votes current-votes), total-votes: (+ (get total-votes current-votes) u1) }
        { yes-votes: (get yes-votes current-votes), no-votes: (+ (get no-votes current-votes) u1), total-votes: (+ (get total-votes current-votes) u1) }
      )
    )
    (ok true)
  )
)

(define-public (approve-amendment (amendment-id uint))
  (let
    (
      (amendment (unwrap! (map-get? budget-amendments { amendment-id: amendment-id }) ERR_AMENDMENT_NOT_FOUND))
      (budget (unwrap! (map-get? budgets { budget-id: (get budget-id amendment) }) ERR_BUDGET_NOT_FOUND))
      (old-amount (get total-amount budget))
      (new-amount (get proposed-amount amendment))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-eq (get status amendment) "pending") ERR_AMENDMENT_NOT_PENDING)
    
    (map-set budget-amendments
      { amendment-id: amendment-id }
      (merge amendment { status: "approved" })
    )
    
    (map-set budgets
      { budget-id: (get budget-id amendment) }
      (merge budget { total-amount: new-amount })
    )
    
    (var-set total-allocated (+ (- (var-get total-allocated) old-amount) new-amount))
    (ok true)
  )
)

(define-read-only (get-amendment (amendment-id uint))
  (map-get? budget-amendments { amendment-id: amendment-id })
)

(define-read-only (get-amendment-votes (amendment-id uint))
  (map-get? amendment-votes { amendment-id: amendment-id })
)


(define-map budget-ratings
  { budget-id: uint }
  { 
    total-timeliness: uint,
    total-quality: uint, 
    total-value: uint,
    rating-count: uint,
    average-score: uint
  }
)

(define-map citizen-ratings
  { citizen: principal, budget-id: uint }
  { 
    timeliness: uint,
    quality: uint,
    value: uint,
    comment: (string-ascii 200),
    rated-at: uint
  }
)

(define-public (rate-budget (budget-id uint) (timeliness uint) (quality uint) (value uint) (comment (string-ascii 200)))
  (let
    (
      (budget (unwrap! (map-get? budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (existing-rating (map-get? citizen-ratings { citizen: tx-sender, budget-id: budget-id }))
      (current-ratings (default-to { total-timeliness: u0, total-quality: u0, total-value: u0, rating-count: u0, average-score: u0 } 
                       (map-get? budget-ratings { budget-id: budget-id })))
    )
    (asserts! (and (<= timeliness u5) (<= quality u5) (<= value u5) (> timeliness u0) (> quality u0) (> value u0)) ERR_INVALID_RATING)
    (asserts! (>= (get spent-amount budget) (get allocated-amount budget)) ERR_BUDGET_NOT_COMPLETED)
    (asserts! (is-none existing-rating) ERR_ALREADY_RATED)
    
    (map-set citizen-ratings
      { citizen: tx-sender, budget-id: budget-id }
      { timeliness: timeliness, quality: quality, value: value, comment: comment, rated-at: stacks-block-height }
    )
    
    (let
      (
        (new-count (+ (get rating-count current-ratings) u1))
        (new-total-timeliness (+ (get total-timeliness current-ratings) timeliness))
        (new-total-quality (+ (get total-quality current-ratings) quality))
        (new-total-value (+ (get total-value current-ratings) value))
        (new-average (/ (+ new-total-timeliness new-total-quality new-total-value) (* new-count u3)))
      )
      (map-set budget-ratings
        { budget-id: budget-id }
        { 
          total-timeliness: new-total-timeliness,
          total-quality: new-total-quality,
          total-value: new-total-value,
          rating-count: new-count,
          average-score: new-average
        }
      )
    )
    (ok true)
  )
)

(define-read-only (get-budget-rating (budget-id uint))
  (map-get? budget-ratings { budget-id: budget-id })
)

(define-read-only (get-citizen-rating (citizen principal) (budget-id uint))
  (map-get? citizen-ratings { citizen: citizen, budget-id: budget-id })
)

(define-read-only (get-department-average-rating (department (string-ascii 50)))
  (ok u0)
)

(define-map department-benchmarks
  { department: (string-ascii 50) }
  {
    avg-efficiency: uint,
    avg-completion-time: uint,
    total-budgets: uint,
    success-rate: uint,
    last-updated: uint
  }
)

(define-map budget-performance
  { budget-id: uint }
  {
    efficiency-score: uint,
    completion-time: uint,
    vs-benchmark: int,
    recorded-at: uint
  }
)

(define-public (record-budget-performance (budget-id uint))
  (let
    (
      (budget (unwrap! (map-get? budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (department (get department budget))
      (current-benchmark (default-to 
        { avg-efficiency: u50, avg-completion-time: u100, total-budgets: u0, success-rate: u50, last-updated: u0 }
        (map-get? department-benchmarks { department: department })))
      (efficiency (unwrap! (get-budget-efficiency budget-id) ERR_BUDGET_NOT_FOUND))
      (completion-time (- stacks-block-height (get created-at budget)))
      (vs-benchmark (- (to-int efficiency) (to-int (get avg-efficiency current-benchmark))))
    )
    (asserts! (>= (get spent-amount budget) (get allocated-amount budget)) ERR_BUDGET_NOT_COMPLETED)
    
    (map-set budget-performance
      { budget-id: budget-id }
      {
        efficiency-score: efficiency,
        completion-time: completion-time,
        vs-benchmark: vs-benchmark,
        recorded-at: stacks-block-height
      }
    )
    
    (let
      (
        (total-budgets (+ (get total-budgets current-benchmark) u1))
        (new-avg-efficiency (/ (+ (* (get avg-efficiency current-benchmark) (get total-budgets current-benchmark)) efficiency) total-budgets))
        (new-avg-time (/ (+ (* (get avg-completion-time current-benchmark) (get total-budgets current-benchmark)) completion-time) total-budgets))
        (new-success-rate (if (>= efficiency u70) 
          (/ (+ (* (get success-rate current-benchmark) (get total-budgets current-benchmark)) u100) total-budgets)
          (/ (* (get success-rate current-benchmark) (get total-budgets current-benchmark)) total-budgets)))
      )
      (map-set department-benchmarks
        { department: department }
        {
          avg-efficiency: new-avg-efficiency,
          avg-completion-time: new-avg-time,
          total-budgets: total-budgets,
          success-rate: new-success-rate,
          last-updated: stacks-block-height
        }
      )
    )
    (ok true)
  )
)

(define-read-only (get-department-benchmark (department (string-ascii 50)))
  (map-get? department-benchmarks { department: department })
)

(define-read-only (get-budget-performance (budget-id uint))
  (map-get? budget-performance { budget-id: budget-id })
)

(define-read-only (compare-department-performance (dept1 (string-ascii 50)) (dept2 (string-ascii 50)))
  (let
    (
      (benchmark1 (map-get? department-benchmarks { department: dept1 }))
      (benchmark2 (map-get? department-benchmarks { department: dept2 }))
    )
    (if (and (is-some benchmark1) (is-some benchmark2))
      (ok {
        dept1-efficiency: (get avg-efficiency (unwrap! benchmark1 ERR_BUDGET_NOT_FOUND)),
        dept2-efficiency: (get avg-efficiency (unwrap! benchmark2 ERR_BUDGET_NOT_FOUND)),
        efficiency-diff: (- (to-int (get avg-efficiency (unwrap! benchmark1 ERR_BUDGET_NOT_FOUND))) 
                            (to-int (get avg-efficiency (unwrap! benchmark2 ERR_BUDGET_NOT_FOUND))))
      })
      ERR_BUDGET_NOT_FOUND
    )
  )
)

(define-map budget-delegations
  { budget-id: uint }
  {
    delegate: principal,
    delegated-by: principal,
    delegated-at: uint,
    active: bool
  }
)

(define-map delegation-history
  { delegation-id: uint }
  {
    budget-id: uint,
    delegate: principal,
    action: (string-ascii 20),
    performed-by: principal,
    performed-at: uint
  }
)

(define-public (delegate-budget-authority (budget-id uint) (delegate principal))
  (let
    (
      (budget (unwrap! (map-get? budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (existing-delegation (map-get? budget-delegations { budget-id: budget-id }))
      (delegation-id (var-get next-delegation-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (or (is-none existing-delegation) (not (get active (unwrap-panic existing-delegation)))) ERR_DELEGATION_EXISTS)
    
    (map-set budget-delegations
      { budget-id: budget-id }
      {
        delegate: delegate,
        delegated-by: tx-sender,
        delegated-at: stacks-block-height,
        active: true
      }
    )
    
    (map-set delegation-history
      { delegation-id: delegation-id }
      {
        budget-id: budget-id,
        delegate: delegate,
        action: "delegated",
        performed-by: tx-sender,
        performed-at: stacks-block-height
      }
    )
    
    (var-set next-delegation-id (+ delegation-id u1))
    (ok true)
  )
)

(define-public (revoke-budget-authority (budget-id uint))
  (let
    (
      (delegation (unwrap! (map-get? budget-delegations { budget-id: budget-id }) ERR_NOT_DELEGATED))
      (delegation-id (var-get next-delegation-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (get active delegation) ERR_NOT_DELEGATED)
    
    (map-set budget-delegations
      { budget-id: budget-id }
      (merge delegation { active: false })
    )
    
    (map-set delegation-history
      { delegation-id: delegation-id }
      {
        budget-id: budget-id,
        delegate: (get delegate delegation),
        action: "revoked",
        performed-by: tx-sender,
        performed-at: stacks-block-height
      }
    )
    
    (var-set next-delegation-id (+ delegation-id u1))
    (ok true)
  )
)

(define-public (complete-milestone-delegated (milestone-id uint))
  (let
    (
      (milestone (unwrap! (map-get? milestones { milestone-id: milestone-id }) ERR_MILESTONE_NOT_FOUND))
      (budget-id (get budget-id milestone))
      (budget (unwrap! (map-get? budgets { budget-id: budget-id }) ERR_BUDGET_NOT_FOUND))
      (delegation (unwrap! (map-get? budget-delegations { budget-id: budget-id }) ERR_NOT_DELEGATED))
    )
    (asserts! (and (is-eq tx-sender (get delegate delegation)) (get active delegation)) ERR_NOT_DELEGATED)
    (asserts! (is-eq (get status milestone) "pending") ERR_INVALID_STATUS)
    
    (map-set milestones
      { milestone-id: milestone-id }
      (merge milestone { 
        status: "completed",
        completion-date: (some stacks-block-height)
      })
    )
    
    (map-set budgets
      { budget-id: budget-id }
      (merge budget { spent-amount: (+ (get spent-amount budget) (get amount milestone)) })
    )
    
    (var-set total-spent (+ (var-get total-spent) (get amount milestone)))
    (ok true)
  )
)

(define-read-only (get-budget-delegate (budget-id uint))
  (map-get? budget-delegations { budget-id: budget-id })
)

(define-read-only (is-budget-delegate (budget-id uint) (principal-to-check principal))
  (match (map-get? budget-delegations { budget-id: budget-id })
    delegation (and (is-eq (get delegate delegation) principal-to-check) (get active delegation))
    false
  )
)