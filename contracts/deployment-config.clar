;; Deployment Configuration Contract
;; Manages contract addresses and cross-contract references

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u600))
(define-constant ERR_NOT_FOUND (err u601))

;; Contract address storage
(define-map contract-addresses
  { contract-name: (string-ascii 50) }
  { address: principal }
)

;; Public functions to set contract addresses (only by owner)
(define-public (set-contract-address (contract-name (string-ascii 50)) (address principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set contract-addresses
      { contract-name: contract-name }
      { address: address }
    )
    (ok true)
  )
)

;; Read-only functions to get contract addresses
(define-read-only (get-contract-address (contract-name (string-ascii 50)))
  (map-get? contract-addresses { contract-name: contract-name })
)

(define-read-only (get-procurement-specialists-address)
  (get-contract-address "procurement-specialists")
)

(define-read-only (get-vendor-evaluation-address)
  (get-contract-address "vendor-evaluation")
)

(define-read-only (get-negotiation-manager-address)
  (get-contract-address "negotiation-manager")
)

(define-read-only (get-performance-monitor-address)
  (get-contract-address "performance-monitor")
)

(define-read-only (get-cost-optimizer-address)
  (get-contract-address "cost-optimizer")
)
