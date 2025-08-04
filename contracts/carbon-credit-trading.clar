;; Carbon Credit Issuance and Trading Contract
;; Creates and facilitates buying and selling of verified carbon credits

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-PROJECT-NOT-FOUND (err u501))
(define-constant ERR-INVALID-INPUT (err u502))
(define-constant ERR-INSUFFICIENT-CREDITS (err u503))
(define-constant ERR-CREDIT-NOT-FOUND (err u504))
(define-constant ERR-CREDIT-RETIRED (err u505))
(define-constant ERR-INVALID-VERIFICATION (err u506))

;; Data Variables
(define-data-var credit-counter uint u0)
(define-data-var total-credits-issued uint u0)
(define-data-var total-credits-retired uint u0)

;; Data Maps
(define-map carbon-credits
  { credit-id: uint }
  {
    project-id: uint,
    quantity: uint,
    vintage: uint,
    credit-type: (string-ascii 50),
    owner: principal,
    issuer: principal,
    issue-date: uint,
    status: (string-ascii 20),
    verification-standard: (string-ascii 50),
    price: uint
  }
)

(define-map credit-ownership
  { owner: principal, credit-id: uint }
  { quantity: uint }
)

(define-map owner-credits-count
  { owner: principal }
  { count: uint }
)

(define-map trading-orders
  { order-id: uint }
  {
    credit-id: uint,
    seller: principal,
    quantity: uint,
    price-per-credit: uint,
    order-type: (string-ascii 10),
    status: (string-ascii 20),
    created-at: uint,
    expires-at: uint
  }
)

(define-map order-counter
  { counter: (string-ascii 10) }
  { value: uint }
)

(define-map credit-retirements
  { retirement-id: uint }
  {
    credit-id: uint,
    quantity: uint,
    retired-by: principal,
    retirement-date: uint,
    retirement-reason: (string-ascii 200),
    beneficiary: (string-ascii 100)
  }
)

(define-map retirement-counter
  { counter: (string-ascii 10) }
  { value: uint }
)

(define-map authorized-issuers
  { issuer: principal }
  { authorized: bool, standards: (string-ascii 200) }
)

(define-map project-verification-status
  { project-id: uint }
  {
    sequestration-verified: bool,
    additionality-verified: bool,
    permanence-verified: bool,
    leakage-verified: bool,
    overall-status: (string-ascii 20)
  }
)

;; Public Functions

;; Authorize a credit issuer
(define-public (authorize-issuer
  (issuer principal)
  (standards (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len standards) u0) ERR-INVALID-INPUT)

    (map-set authorized-issuers
      { issuer: issuer }
      { authorized: true, standards: standards }
    )

    (ok true)
  )
)

;; Update project verification status
(define-public (update-verification-status
  (project-id uint)
  (sequestration-verified bool)
  (additionality-verified bool)
  (permanence-verified bool)
  (leakage-verified bool))
  (let
    ((issuer-info (unwrap! (map-get? authorized-issuers { issuer: tx-sender }) ERR-NOT-AUTHORIZED))
     (overall-status (if (and sequestration-verified (and additionality-verified (and permanence-verified leakage-verified)))
                       "fully-verified"
                       "partially-verified")))

    (asserts! (get authorized issuer-info) ERR-NOT-AUTHORIZED)

    (map-set project-verification-status
      { project-id: project-id }
      {
        sequestration-verified: sequestration-verified,
        additionality-verified: additionality-verified,
        permanence-verified: permanence-verified,
        leakage-verified: leakage-verified,
        overall-status: overall-status
      }
    )

    (ok overall-status)
  )
)

;; Issue carbon credits
(define-public (issue-credits
  (project-id uint)
  (quantity uint)
  (vintage uint)
  (credit-type (string-ascii 50))
  (owner principal)
  (verification-standard (string-ascii 50))
  (price uint))
  (let
    ((issuer-info (unwrap! (map-get? authorized-issuers { issuer: tx-sender }) ERR-NOT-AUTHORIZED))
     (verification (unwrap! (map-get? project-verification-status { project-id: project-id }) ERR-INVALID-VERIFICATION))
     (credit-id (+ (var-get credit-counter) u1)))

    (asserts! (get authorized issuer-info) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get overall-status verification) "fully-verified") ERR-INVALID-VERIFICATION)
    (asserts! (> quantity u0) ERR-INVALID-INPUT)
    (asserts! (> vintage u2020) ERR-INVALID-INPUT)
    (asserts! (> (len credit-type) u0) ERR-INVALID-INPUT)
    (asserts! (>= price u0) ERR-INVALID-INPUT)

    (map-set carbon-credits
      { credit-id: credit-id }
      {
        project-id: project-id,
        quantity: quantity,
        vintage: vintage,
        credit-type: credit-type,
        owner: owner,
        issuer: tx-sender,
        issue-date: block-height,
        status: "active",
        verification-standard: verification-standard,
        price: price
      }
    )

    (map-set credit-ownership
      { owner: owner, credit-id: credit-id }
      { quantity: quantity }
    )

    (let
      ((current-count (default-to { count: u0 } (map-get? owner-credits-count { owner: owner }))))
      (map-set owner-credits-count
        { owner: owner }
        { count: (+ (get count current-count) u1) }
      )
    )

    (var-set credit-counter credit-id)
    (var-set total-credits-issued (+ (var-get total-credits-issued) quantity))

    (ok credit-id)
  )
)

;; Create sell order
(define-public (create-sell-order
  (credit-id uint)
  (quantity uint)
  (price-per-credit uint)
  (expires-at uint))
  (let
    ((credit (unwrap! (map-get? carbon-credits { credit-id: credit-id }) ERR-CREDIT-NOT-FOUND))
     (ownership (unwrap! (map-get? credit-ownership { owner: tx-sender, credit-id: credit-id }) ERR-NOT-AUTHORIZED))
     (order-id (+ (default-to u0 (get value (map-get? order-counter { counter: "sell" }))) u1)))

    (asserts! (is-eq (get owner credit) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status credit) "active") ERR-CREDIT-RETIRED)
    (asserts! (<= quantity (get quantity ownership)) ERR-INSUFFICIENT-CREDITS)
    (asserts! (> price-per-credit u0) ERR-INVALID-INPUT)
    (asserts! (> expires-at block-height) ERR-INVALID-INPUT)

    (map-set trading-orders
      { order-id: order-id }
      {
        credit-id: credit-id,
        seller: tx-sender,
        quantity: quantity,
        price-per-credit: price-per-credit,
        order-type: "sell",
        status: "active",
        created-at: block-height,
        expires-at: expires-at
      }
    )

    (map-set order-counter
      { counter: "sell" }
      { value: order-id }
    )

    (ok order-id)
  )
)

;; Execute buy order
(define-public (execute-buy-order
  (order-id uint)
  (quantity uint))
  (let
    ((order (unwrap! (map-get? trading-orders { order-id: order-id }) ERR-PROJECT-NOT-FOUND))
     (credit (unwrap! (map-get? carbon-credits { credit-id: (get credit-id order) }) ERR-CREDIT-NOT-FOUND))
     (seller-ownership (unwrap! (map-get? credit-ownership { owner: (get seller order), credit-id: (get credit-id order) }) ERR-NOT-AUTHORIZED))
     (total-cost (* quantity (get price-per-credit order))))

    (asserts! (is-eq (get status order) "active") ERR-INVALID-INPUT)
    (asserts! (<= quantity (get quantity order)) ERR-INSUFFICIENT-CREDITS)
    (asserts! (> block-height (get expires-at order)) ERR-INVALID-INPUT)

    ;; Update seller ownership
    (map-set credit-ownership
      { owner: (get seller order), credit-id: (get credit-id order) }
      { quantity: (- (get quantity seller-ownership) quantity) }
    )

    ;; Update buyer ownership
    (let
      ((buyer-ownership (default-to { quantity: u0 } (map-get? credit-ownership { owner: tx-sender, credit-id: (get credit-id order) }))))
      (map-set credit-ownership
        { owner: tx-sender, credit-id: (get credit-id order) }
        { quantity: (+ (get quantity buyer-ownership) quantity) }
      )
    )

    ;; Update credit owner if full quantity transferred
    (if (is-eq quantity (get quantity order))
      (map-set carbon-credits
        { credit-id: (get credit-id order) }
        (merge credit { owner: tx-sender })
      )
      true
    )

    ;; Update order status
    (map-set trading-orders
      { order-id: order-id }
      (merge order {
        status: (if (is-eq quantity (get quantity order)) "completed" "partially-filled"),
        quantity: (- (get quantity order) quantity)
      })
    )

    (ok total-cost)
  )
)

;; Retire carbon credits
(define-public (retire-credits
  (credit-id uint)
  (quantity uint)
  (retirement-reason (string-ascii 200))
  (beneficiary (string-ascii 100)))
  (let
    ((credit (unwrap! (map-get? carbon-credits { credit-id: credit-id }) ERR-CREDIT-NOT-FOUND))
     (ownership (unwrap! (map-get? credit-ownership { owner: tx-sender, credit-id: credit-id }) ERR-NOT-AUTHORIZED))
     (retirement-id (+ (default-to u0 (get value (map-get? retirement-counter { counter: "retire" }))) u1)))

    (asserts! (is-eq (get owner credit) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status credit) "active") ERR-CREDIT-RETIRED)
    (asserts! (<= quantity (get quantity ownership)) ERR-INSUFFICIENT-CREDITS)
    (asserts! (> (len retirement-reason) u0) ERR-INVALID-INPUT)

    (map-set credit-retirements
      { retirement-id: retirement-id }
      {
        credit-id: credit-id,
        quantity: quantity,
        retired-by: tx-sender,
        retirement-date: block-height,
        retirement-reason: retirement-reason,
        beneficiary: beneficiary
      }
    )

    ;; Update ownership
    (map-set credit-ownership
      { owner: tx-sender, credit-id: credit-id }
      { quantity: (- (get quantity ownership) quantity) }
    )

    ;; Update credit status if fully retired
    (if (is-eq quantity (get quantity credit))
      (map-set carbon-credits
        { credit-id: credit-id }
        (merge credit { status: "retired" })
      )
      true
    )

    (map-set retirement-counter
      { counter: "retire" }
      { value: retirement-id }
    )

    (var-set total-credits-retired (+ (var-get total-credits-retired) quantity))

    (ok retirement-id)
  )
)

;; Read-only Functions

;; Get credit details
(define-read-only (get-credit (credit-id uint))
  (map-get? carbon-credits { credit-id: credit-id })
)

;; Get credit ownership
(define-read-only (get-ownership (owner principal) (credit-id uint))
  (map-get? credit-ownership { owner: owner, credit-id: credit-id })
)

;; Get trading order
(define-read-only (get-order (order-id uint))
  (map-get? trading-orders { order-id: order-id })
)

;; Get retirement details
(define-read-only (get-retirement (retirement-id uint))
  (map-get? credit-retirements { retirement-id: retirement-id })
)

;; Get project verification status
(define-read-only (get-project-verification (project-id uint))
  (map-get? project-verification-status { project-id: project-id })
)

;; Check if issuer is authorized
(define-read-only (is-authorized-issuer (issuer principal))
  (match (map-get? authorized-issuers { issuer: issuer })
    issuer-info (get authorized issuer-info)
    false
  )
)

;; Get owner credits count
(define-read-only (get-owner-credits-count (owner principal))
  (default-to { count: u0 } (map-get? owner-credits-count { owner: owner }))
)

;; Get market statistics
(define-read-only (get-market-stats)
  {
    total-credits-issued: (var-get total-credits-issued),
    total-credits-retired: (var-get total-credits-retired),
    active-credits: (- (var-get total-credits-issued) (var-get total-credits-retired)),
    credit-counter: (var-get credit-counter)
  }
)

;; Calculate credit price with market factors
(define-read-only (calculate-market-price (base-price uint) (demand-factor uint) (supply-factor uint))
  (let
    ((adjusted-price (/ (* base-price demand-factor) supply-factor)))
    (if (> adjusted-price u0) adjusted-price u1)
  )
)
