;; Cost Optimizer Contract
;; Implements cost reduction strategies and savings tracking

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_NOT_FOUND (err u501))
(define-constant ERR_INVALID_AMOUNT (err u502))

;; Data structures
(define-map cost-baselines
  { category: (string-ascii 50), period: uint }
  {
    baseline-cost: uint,
    target-reduction: uint,
    actual-cost: uint,
    savings-achieved: uint,
    period-start: uint,
    period-end: uint
  }
)

(define-map savings-opportunities
  { opportunity-id: uint }
  {
    category: (string-ascii 50),
    description: (string-ascii 200),
    potential-savings: uint,
    implementation-cost: uint,
    roi-percentage: uint,
    priority: uint,
    status: (string-ascii 20),
    created-block: uint
  }
)

(define-map budget-allocations
  { category: (string-ascii 50), period: uint }
  {
    allocated-budget: uint,
    spent-amount: uint,
    remaining-budget: uint,
    variance-percentage: uint,
    last-updated: uint
  }
)

(define-data-var next-opportunity-id uint u1)
(define-data-var total-savings uint u0)
(define-data-var current-budget-period uint u1)

;; Public functions

(define-public (set-cost-baseline
  (category (string-ascii 50))
  (baseline-cost uint)
  (target-reduction uint)
)
  (let ((period (var-get current-budget-period)))
    (asserts! (is-verified-specialist tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> baseline-cost u0) ERR_INVALID_AMOUNT)

    (map-set cost-baselines
      { category: category, period: period }
      {
        baseline-cost: baseline-cost,
        target-reduction: target-reduction,
        actual-cost: u0,
        savings-achieved: u0,
        period-start: block-height,
        period-end: (+ block-height u4032) ;; ~4 weeks in blocks
      }
    )
    (ok true)
  )
)

(define-public (record-actual-cost (category (string-ascii 50)) (actual-cost uint))
  (let (
    (period (var-get current-budget-period))
    (baseline-data (unwrap! (map-get? cost-baselines { category: category, period: period }) ERR_NOT_FOUND))
  )
    (asserts! (is-verified-specialist tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> actual-cost u0) ERR_INVALID_AMOUNT)

    (let ((savings (if (> (get baseline-cost baseline-data) actual-cost)
                      (- (get baseline-cost baseline-data) actual-cost)
                      u0)))
      (map-set cost-baselines
        { category: category, period: period }
        (merge baseline-data {
          actual-cost: actual-cost,
          savings-achieved: savings
        })
      )

      ;; Update total savings
      (var-set total-savings (+ (var-get total-savings) savings))
      (ok savings)
    )
  )
)

(define-public (create-savings-opportunity
  (category (string-ascii 50))
  (description (string-ascii 200))
  (potential-savings uint)
  (implementation-cost uint)
  (priority uint)
)
  (let ((opportunity-id (var-get next-opportunity-id)))
    (asserts! (is-verified-specialist tx-sender) ERR_UNAUTHORIZED)
    (asserts! (and (> potential-savings u0) (<= priority u5)) ERR_INVALID_AMOUNT)

    (let ((roi (if (> implementation-cost u0)
                  (/ (* potential-savings u100) implementation-cost)
                  u0)))
      (map-set savings-opportunities
        { opportunity-id: opportunity-id }
        {
          category: category,
          description: description,
          potential-savings: potential-savings,
          implementation-cost: implementation-cost,
          roi-percentage: roi,
          priority: priority,
          status: "identified",
          created-block: block-height
        }
      )

      (var-set next-opportunity-id (+ opportunity-id u1))
      (ok opportunity-id)
    )
  )
)

(define-public (allocate-budget (category (string-ascii 50)) (amount uint))
  (let ((period (var-get current-budget-period)))
    (asserts! (is-verified-specialist tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (map-set budget-allocations
      { category: category, period: period }
      {
        allocated-budget: amount,
        spent-amount: u0,
        remaining-budget: amount,
        variance-percentage: u0,
        last-updated: block-height
      }
    )
    (ok true)
  )
)

(define-public (record-spending (category (string-ascii 50)) (amount uint))
  (let (
    (period (var-get current-budget-period))
    (budget-data (unwrap! (map-get? budget-allocations { category: category, period: period }) ERR_NOT_FOUND))
  )
    (asserts! (is-verified-specialist tx-sender) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)

    (let (
      (new-spent (+ (get spent-amount budget-data) amount))
      (new-remaining (if (> (get allocated-budget budget-data) new-spent)
                        (- (get allocated-budget budget-data) new-spent)
                        u0))
      (variance (/ (* (- (get allocated-budget budget-data) new-remaining) u100)
                   (get allocated-budget budget-data)))
    )
      (map-set budget-allocations
        { category: category, period: period }
        (merge budget-data {
          spent-amount: new-spent,
          remaining-budget: new-remaining,
          variance-percentage: variance,
          last-updated: block-height
        })
      )
      (ok new-remaining)
    )
  )
)

;; Read-only functions

(define-read-only (get-cost-baseline (category (string-ascii 50)) (period uint))
  (map-get? cost-baselines { category: category, period: period })
)

(define-read-only (get-savings-opportunity (opportunity-id uint))
  (map-get? savings-opportunities { opportunity-id: opportunity-id })
)

(define-read-only (get-budget-allocation (category (string-ascii 50)) (period uint))
  (map-get? budget-allocations { category: category, period: period })
)

(define-read-only (get-total-savings)
  (var-get total-savings)
)

(define-read-only (calculate-savings-rate (category (string-ascii 50)) (period uint))
  (match (map-get? cost-baselines { category: category, period: period })
    baseline-data
      (if (> (get baseline-cost baseline-data) u0)
        (some (/ (* (get savings-achieved baseline-data) u100)
                 (get baseline-cost baseline-data)))
        none)
    none
  )
)

(define-read-only (get-budget-utilization (category (string-ascii 50)) (period uint))
  (match (map-get? budget-allocations { category: category, period: period })
    budget-data
      (if (> (get allocated-budget budget-data) u0)
        (some (/ (* (get spent-amount budget-data) u100)
                 (get allocated-budget budget-data)))
        none)
    none
  )
)

(define-read-only (get-current-budget-period)
  (var-get current-budget-period)
)

;; Temporary verification function - in production this would call the specialists contract
(define-private (is-verified-specialist (specialist principal))
  ;; For demo purposes, we'll allow any specialist
  ;; In production: (contract-call? 'SP123...procurement-specialists is-verified-specialist specialist)
  true
)
