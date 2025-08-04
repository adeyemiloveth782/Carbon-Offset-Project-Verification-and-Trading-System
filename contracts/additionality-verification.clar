;; Additionality Verification Contract
;; Ensures carbon offset projects would not occur without carbon financing

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-PROJECT-NOT-FOUND (err u201))
(define-constant ERR-INVALID-INPUT (err u202))
(define-constant ERR-ALREADY-VERIFIED (err u203))
(define-constant ERR-VERIFICATION-FAILED (err u204))

;; Data Variables
(define-data-var verification-counter uint u0)

;; Data Maps
(define-map additionality-verifications
  { project-id: uint }
  {
    baseline-scenario: (string-ascii 200),
    financial-analysis: (string-ascii 200),
    barrier-analysis: (string-ascii 200),
    common-practice: (string-ascii 200),
    verifier: principal,
    verification-date: uint,
    status: (string-ascii 20),
    confidence-score: uint
  }
)

(define-map verification-evidence
  { project-id: uint, evidence-id: uint }
  {
    evidence-type: (string-ascii 50),
    description: (string-ascii 200),
    submitted-by: principal,
    submission-date: uint,
    verified: bool
  }
)

(define-map project-evidence-count
  { project-id: uint }
  { count: uint }
)

(define-map authorized-verifiers
  { verifier: principal }
  { authorized: bool, specialization: (string-ascii 100) }
)

;; Public Functions

;; Authorize a verifier
(define-public (authorize-verifier
  (verifier principal)
  (specialization (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len specialization) u0) ERR-INVALID-INPUT)

    (map-set authorized-verifiers
      { verifier: verifier }
      { authorized: true, specialization: specialization }
    )

    (ok true)
  )
)

;; Submit additionality verification
(define-public (verify-additionality
  (project-id uint)
  (baseline-scenario (string-ascii 200))
  (financial-analysis (string-ascii 200))
  (barrier-analysis (string-ascii 200))
  (common-practice (string-ascii 200))
  (confidence-score uint))
  (let
    ((verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR-NOT-AUTHORIZED))
     (existing-verification (map-get? additionality-verifications { project-id: project-id })))

    (asserts! (get authorized verifier-info) ERR-NOT-AUTHORIZED)
    (asserts! (is-none existing-verification) ERR-ALREADY-VERIFIED)
    (asserts! (and (>= confidence-score u1) (<= confidence-score u100)) ERR-INVALID-INPUT)
    (asserts! (> (len baseline-scenario) u0) ERR-INVALID-INPUT)

    (map-set additionality-verifications
      { project-id: project-id }
      {
        baseline-scenario: baseline-scenario,
        financial-analysis: financial-analysis,
        barrier-analysis: barrier-analysis,
        common-practice: common-practice,
        verifier: tx-sender,
        verification-date: block-height,
        status: "verified",
        confidence-score: confidence-score
      }
    )

    (var-set verification-counter (+ (var-get verification-counter) u1))
    (ok true)
  )
)

;; Submit evidence for additionality
(define-public (submit-evidence
  (project-id uint)
  (evidence-type (string-ascii 50))
  (description (string-ascii 200)))
  (let
    ((evidence-count (default-to { count: u0 } (map-get? project-evidence-count { project-id: project-id })))
     (new-evidence-id (+ (get count evidence-count) u1)))

    (asserts! (> (len evidence-type) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    (map-set verification-evidence
      { project-id: project-id, evidence-id: new-evidence-id }
      {
        evidence-type: evidence-type,
        description: description,
        submitted-by: tx-sender,
        submission-date: block-height,
        verified: false
      }
    )

    (map-set project-evidence-count
      { project-id: project-id }
      { count: new-evidence-id }
    )

    (ok new-evidence-id)
  )
)

;; Verify submitted evidence
(define-public (verify-evidence
  (project-id uint)
  (evidence-id uint)
  (verified bool))
  (let
    ((verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR-NOT-AUTHORIZED))
     (evidence (unwrap! (map-get? verification-evidence { project-id: project-id, evidence-id: evidence-id }) ERR-PROJECT-NOT-FOUND)))

    (asserts! (get authorized verifier-info) ERR-NOT-AUTHORIZED)

    (map-set verification-evidence
      { project-id: project-id, evidence-id: evidence-id }
      (merge evidence { verified: verified })
    )

    (ok true)
  )
)

;; Update verification status
(define-public (update-verification-status
  (project-id uint)
  (new-status (string-ascii 20)))
  (let
    ((verification (unwrap! (map-get? additionality-verifications { project-id: project-id }) ERR-PROJECT-NOT-FOUND))
     (verifier-info (unwrap! (map-get? authorized-verifiers { verifier: tx-sender }) ERR-NOT-AUTHORIZED)))

    (asserts! (get authorized verifier-info) ERR-NOT-AUTHORIZED)
    (asserts! (> (len new-status) u0) ERR-INVALID-INPUT)

    (map-set additionality-verifications
      { project-id: project-id }
      (merge verification { status: new-status })
    )

    (ok true)
  )
)

;; Read-only Functions

;; Get additionality verification
(define-read-only (get-verification (project-id uint))
  (map-get? additionality-verifications { project-id: project-id })
)

;; Get evidence details
(define-read-only (get-evidence (project-id uint) (evidence-id uint))
  (map-get? verification-evidence { project-id: project-id, evidence-id: evidence-id })
)

;; Get evidence count for project
(define-read-only (get-evidence-count (project-id uint))
  (default-to { count: u0 } (map-get? project-evidence-count { project-id: project-id }))
)

;; Check if verifier is authorized
(define-read-only (is-authorized-verifier (verifier principal))
  (match (map-get? authorized-verifiers { verifier: verifier })
    verifier-info (get authorized verifier-info)
    false
  )
)

;; Get verifier info
(define-read-only (get-verifier-info (verifier principal))
  (map-get? authorized-verifiers { verifier: verifier })
)

;; Check if project has valid additionality
(define-read-only (has-valid-additionality (project-id uint))
  (match (map-get? additionality-verifications { project-id: project-id })
    verification (and
      (is-eq (get status verification) "verified")
      (>= (get confidence-score verification) u70))
    false
  )
)

;; Get verification counter
(define-read-only (get-verification-counter)
  (var-get verification-counter)
)
