;; Noetic Commerce - Consciousness-based knowledge trade
;;
;; A decentralized platform for exchanging knowledge resources through tokenized time units
;; Enables scholastic-minded individuals to share expertise and learn from others in a secure, trustless environment with built-in reputation systems

;; ========== DATA VAULT STRUCTURES ==========
;; Primary mapping structures for resource accounting and tracking

;; Track scholar wisdom holdings and resource coins
(define-map wisdom-reserves principal uint)      ;; Scholar's available wisdom time units
(define-map resource-reserves principal uint)    ;; Scholar's available resource tokens
(define-map wisdom-marketplace {scholar: principal} {time-units: uint, unit-value: uint})

;; ========== ACCREDITATION FRAMEWORK ==========

;; Validation registry for verified knowledge providers
(define-map accredited-scholars principal bool)
(define-map premium-wisdom-offerings {scholar: principal} {time-units: uint, unit-value: uint, accredited: bool})

;; ========== ECOSYSTEM PARAMETERS ==========
(define-data-var unit-acquisition-cost uint u10)  
(define-data-var individual-wisdom-ceiling uint u100) 
(define-data-var ecosystem-tribute-rate uint u10)
(define-data-var collective-wisdom-repository uint u0) 
(define-data-var wisdom-repository-capacity uint u1000) 

;; ========== GOVERNANCE CONTROLS AND RESPONSE CODES ==========

(define-constant response-insufficient-resources (err u201))
(define-constant response-invalid-wisdom-request (err u202))
(define-constant custodian-identity tx-sender)
(define-constant response-custodian-restricted (err u200))
(define-constant response-invalid-valuation (err u203))
(define-constant response-zero-limit-invalid (err u209))
(define-constant response-capacity-reduction-prohibited (err u210))
(define-constant response-accreditation-required (err u211))
(define-constant response-rating-below-minimum (err u212))
(define-constant response-capacity-threshold-breached (err u204))
(define-constant response-operation-not-permitted (err u205))
(define-constant response-wisdom-threshold-breached (err u206))
(define-constant response-zero-amount-invalid (err u207))
(define-constant response-excessive-tribute-rate (err u208))
(define-constant response-rating-above-maximum (err u213))
(define-constant response-discount-below-minimum (err u214))
(define-constant response-discount-above-maximum (err u215))

;; ========== COLLABORATIVE SYMPOSIUMS ==========

(define-map symposium-registry uint {facilitator: principal, participants: (list 10 principal), duration: uint, contribution: uint, status: (string-ascii 20)})
(define-data-var symposium-counter uint u0)

;; ========== REPUTATION MECHANISM ==========

(define-map scholar-assessment {mentor: principal, apprentice: principal} uint)
(define-map scholar-reputation principal {wisdom-points: uint, assessment-count: uint})

;; ========== VALUE BUNDLES ==========

(define-map wisdom-bundles {scholar: principal} {time-units: uint, unit-value: uint, value-multiplier: uint})

;; ========== UTILITY OPERATIONS ==========

(define-private (modify-wisdom-repository (units-change int))
  (let (
    (current-repository (var-get collective-wisdom-repository))
    (updated-repository (if (< units-change 0)
                     ;; If removing units, ensure non-negative result
                     (if (>= current-repository (to-uint (- 0 units-change)))
                         (- current-repository (to-uint (- 0 units-change)))
                         u0)
                     ;; If adding units
                     (+ current-repository (to-uint units-change))))
  )
    ;; Verify capacity constraints
    (asserts! (<= updated-repository (var-get wisdom-repository-capacity)) response-capacity-threshold-breached)
    ;; Update the repository size
    (var-set collective-wisdom-repository updated-repository)
    (ok true)))

(define-private (calculate-tribute (exchange-value uint))
  (let ((tribute-rate (var-get ecosystem-tribute-rate)))
    (/ (* exchange-value tribute-rate) u100)))

;; ========== CORE PROTOCOL FUNCTIONS ==========

;; Register new wisdom time units to scholar's account
(define-public (register-wisdom-units (units uint))
  (let (
    (scholar tx-sender)
    (current-units (default-to u0 (map-get? wisdom-reserves scholar)))
    (max-allowed (var-get individual-wisdom-ceiling))
    (registration-cost (* units (var-get unit-acquisition-cost)))
    (scholar-resources (default-to u0 (map-get? resource-reserves scholar)))
  )
    ;; Validate the registration request
    (asserts! (> units u0) response-invalid-wisdom-request)
    (asserts! (<= (+ current-units units) max-allowed) response-wisdom-threshold-breached)
    (asserts! (>= scholar-resources registration-cost) response-insufficient-resources)

    ;; Update scholar's wisdom and resource balances
    (map-set wisdom-reserves scholar (+ current-units units))
    (map-set resource-reserves scholar (- scholar-resources registration-cost))

    ;; Transfer registration fee to ecosystem custodian
    (map-set resource-reserves custodian-identity 
             (+ (default-to u0 (map-get? resource-reserves custodian-identity)) registration-cost))

    (ok true)))

;; Offer wisdom units to the marketplace
(define-public (offer-wisdom (units uint) (value-per-unit uint))
  (let (
    (current-units (default-to u0 (map-get? wisdom-reserves tx-sender)))
    (currently-offered (get time-units (default-to {time-units: u0, unit-value: u0} 
                                        (map-get? wisdom-marketplace {scholar: tx-sender}))))
    (total-offered (+ units currently-offered))
  )
    ;; Validate the offering
    (asserts! (> units u0) response-invalid-wisdom-request)
    (asserts! (> value-per-unit u0) response-invalid-valuation)
    (asserts! (>= current-units total-offered) response-insufficient-resources)

    ;; Update the collective wisdom repository
    (try! (modify-wisdom-repository (to-int units)))

    ;; Update the marketplace with the new offering
    (map-set wisdom-marketplace {scholar: tx-sender} 
             {time-units: total-offered, unit-value: value-per-unit})

    (ok true)))

;; Acquire wisdom from another scholar
(define-public (acquire-wisdom (provider principal) (units uint))
  (let (
    (offering (default-to {time-units: u0, unit-value: u0} 
                         (map-get? wisdom-marketplace {scholar: provider})))
    (exchange-value (* units (get unit-value offering)))
    (ecosystem-tribute (calculate-tribute exchange-value))
    (total-cost (+ exchange-value ecosystem-tribute))
    (provider-units (default-to u0 (map-get? wisdom-reserves provider)))
    (seeker-resources (default-to u0 (map-get? resource-reserves tx-sender)))
    (provider-resources (default-to u0 (map-get? resource-reserves provider)))
  )
    ;; Verify conditions
    (asserts! (not (is-eq tx-sender provider)) response-operation-not-permitted)
    (asserts! (> units u0) response-invalid-wisdom-request)
    (asserts! (>= (get time-units offering) units) response-insufficient-resources)
    (asserts! (>= provider-units units) response-insufficient-resources)
    (asserts! (>= seeker-resources total-cost) response-insufficient-resources)

    ;; Update provider's wisdom balance and marketplace offerings
    (map-set wisdom-reserves provider (- provider-units units))
    (map-set wisdom-marketplace {scholar: provider} 
             {time-units: (- (get time-units offering) units), unit-value: (get unit-value offering)})

    ;; Update token balances
    (map-set resource-reserves tx-sender (- seeker-resources total-cost))
    (map-set resource-reserves provider (+ provider-resources exchange-value))
    (map-set wisdom-reserves tx-sender (+ (default-to u0 (map-get? wisdom-reserves tx-sender)) units))

    ;; Add tribute to custodian balance
    (map-set resource-reserves custodian-identity 
             (+ (default-to u0 (map-get? resource-reserves custodian-identity)) ecosystem-tribute))

    (ok true)))

;; Offer certified premium wisdom (requires accreditation)
(define-public (offer-premium-wisdom (units uint) (value-per-unit uint))
  (let (
    (current-units (default-to u0 (map-get? wisdom-reserves tx-sender)))
    (is-accredited (default-to false (map-get? accredited-scholars tx-sender)))
    (currently-offered (get time-units (default-to {time-units: u0, unit-value: u0} 
                                       (map-get? wisdom-marketplace {scholar: tx-sender}))))
    (total-offered (+ units currently-offered))
  )
    ;; Validate the premium offering
    (asserts! (> units u0) response-invalid-wisdom-request)
    (asserts! (> value-per-unit u0) response-invalid-valuation)
    (asserts! is-accredited response-accreditation-required)
    (asserts! (>= current-units total-offered) response-insufficient-resources)

    ;; Update the collective wisdom repository
    (try! (modify-wisdom-repository (to-int units)))

    ;; Update standard wisdom offerings
    (map-set wisdom-marketplace {scholar: tx-sender} 
             {time-units: total-offered, unit-value: value-per-unit})

    ;; Update premium wisdom offerings
    (map-set premium-wisdom-offerings {scholar: tx-sender} 
             {time-units: units, unit-value: value-per-unit, accredited: true})

    (ok true)))

;; Create a bundled package of wisdom units at a discount
(define-public (create-wisdom-bundle (units uint) (value-per-unit uint) (discount-rate uint))
  (let (
    (current-units (default-to u0 (map-get? wisdom-reserves tx-sender)))
    (currently-offered (get time-units (default-to {time-units: u0, unit-value: u0} 
                                      (map-get? wisdom-marketplace {scholar: tx-sender}))))
    (current-bundle (default-to {time-units: u0, unit-value: u0, value-multiplier: u0} 
                              (map-get? wisdom-bundles {scholar: tx-sender})))
    (total-offered (+ units currently-offered))
    (total-bundled-units (+ units (get time-units current-bundle)))
  )
    ;; Validate the bundle creation
    (asserts! (> units u0) response-invalid-wisdom-request)
    (asserts! (> value-per-unit u0) response-invalid-valuation)
    (asserts! (> discount-rate u0) response-discount-below-minimum)
    (asserts! (<= discount-rate u50) response-discount-above-maximum)
    (asserts! (>= current-units total-offered) response-insufficient-resources)

    ;; Update the collective wisdom repository
    (try! (modify-wisdom-repository (to-int units)))

    ;; Update wisdom availability
    (map-set wisdom-marketplace {scholar: tx-sender} 
             {time-units: total-offered, unit-value: value-per-unit})

    ;; Create or update the bundle offering
    (map-set wisdom-bundles {scholar: tx-sender} {
      time-units: total-bundled-units, 
      unit-value: value-per-unit, 
      value-multiplier: discount-rate
    })

    (ok true)))

;; Initialize a collective wisdom symposium
(define-public (establish-symposium (attendees (list 10 principal)) (duration uint) (contribution uint))
  (let (
    (current-units (default-to u0 (map-get? wisdom-reserves tx-sender)))
    (symposium-id (var-get symposium-counter))
    (attendee-count (len attendees))
    (total-symposium-units (* duration attendee-count))
  )
    ;; Validate the symposium parameters
    (asserts! (> duration u0) response-invalid-wisdom-request)
    (asserts! (> contribution u0) response-invalid-valuation)
    (asserts! (>= current-units total-symposium-units) response-insufficient-resources)

    ;; Update the wisdom repository
    (try! (modify-wisdom-repository (to-int total-symposium-units)))

    ;; Update facilitator's wisdom balance
    (map-set wisdom-reserves tx-sender (- current-units total-symposium-units))

    ;; Increment the symposium counter
    (var-set symposium-counter (+ symposium-id u1))

    (ok symposium-id)))

;; Evaluate a scholar after knowledge exchange
(define-public (assess-scholar (scholar principal) (rating uint))
  (let (
    (scholar-metrics (default-to {wisdom-points: u0, assessment-count: u0} 
                                (map-get? scholar-reputation scholar)))
    (current-total (get wisdom-points scholar-metrics))
    (current-count (get assessment-count scholar-metrics))
    (new-total (+ current-total rating))
    (new-count (+ current-count u1))
  )
    ;; Validate the assessment
    (asserts! (not (is-eq tx-sender scholar)) response-operation-not-permitted)
    (asserts! (>= rating u1) response-rating-below-minimum)
    (asserts! (<= rating u5) response-rating-above-maximum)

    ;; Update the scholar's reputation data
    (map-set scholar-assessment {mentor: scholar, apprentice: tx-sender} rating)
    (map-set scholar-reputation scholar {wisdom-points: new-total, assessment-count: new-count})

    (ok true)))

;; Deposit resource tokens into the ecosystem
(define-public (deposit-resources (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? resource-reserves tx-sender)))
    (new-balance (+ current-balance amount))
  )
    ;; Validate the deposit
    (asserts! (> amount u0) response-zero-amount-invalid)

    ;; Transfer tokens from scholar to protocol
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update scholar's resource balance in the ecosystem
    (map-set resource-reserves tx-sender new-balance)

    (ok true)))

;; Withdraw resource tokens from the ecosystem
(define-public (withdraw-resources (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? resource-reserves tx-sender)))
    (protocol-balance (as-contract (stx-get-balance tx-sender)))
  )
    ;; Validate the withdrawal
    (asserts! (> amount u0) response-zero-amount-invalid)
    (asserts! (>= current-balance amount) response-insufficient-resources)
    (asserts! (>= protocol-balance amount) response-insufficient-resources)

    ;; Transfer tokens from protocol to scholar
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))

    ;; Update scholar's resource balance in the ecosystem
    (map-set resource-reserves tx-sender (- current-balance amount))

    (ok true)))

;; Reclaim offered wisdom units from the marketplace
(define-public (reclaim-offered-wisdom (units uint))
  (let (
    (offering (default-to {time-units: u0, unit-value: u0} 
                         (map-get? wisdom-marketplace {scholar: tx-sender})))
    (available-units (get time-units offering))
    (scholar-units (default-to u0 (map-get? wisdom-reserves tx-sender)))
  )
    ;; Validate the reclamation
    (asserts! (> units u0) response-invalid-wisdom-request)
    (asserts! (>= available-units units) response-insufficient-resources)

    ;; Update the scholar's offered wisdom
    (map-set wisdom-marketplace {scholar: tx-sender} {
      time-units: (- available-units units),
      unit-value: (get unit-value offering)
    })

    ;; Update scholar's wisdom balance
    (map-set wisdom-reserves tx-sender scholar-units)

    ;; Handle premium offerings if applicable
    (if (is-some (map-get? premium-wisdom-offerings {scholar: tx-sender}))
        (let (
          (premium-offering (unwrap-panic (map-get? premium-wisdom-offerings {scholar: tx-sender})))
          (premium-units (get time-units premium-offering))
        )
          (if (>= premium-units units)
              (map-set premium-wisdom-offerings {scholar: tx-sender} {
                time-units: (- premium-units units),
                unit-value: (get unit-value premium-offering),
                accredited: (get accredited premium-offering)
              })
              (map-delete premium-wisdom-offerings {scholar: tx-sender})
          )
        )
        true
    )

    (ok true)))

;; Update ecosystem parameters (custodian only)
(define-public (reconfigure-ecosystem-parameters (new-unit-cost uint) 
                                              (new-tribute-rate uint) 
                                              (new-scholar-limit uint) 
                                              (new-repository-capacity uint))
  (begin
    ;; Verify custodian authorization
    (asserts! (is-eq tx-sender custodian-identity) response-custodian-restricted)

    ;; Validate the configuration parameters
    (asserts! (> new-unit-cost u0) response-invalid-valuation)
    (asserts! (<= new-tribute-rate u30) response-excessive-tribute-rate)
    (asserts! (> new-scholar-limit u0) response-zero-limit-invalid)
    (asserts! (>= new-repository-capacity (var-get collective-wisdom-repository)) 
              response-capacity-reduction-prohibited)

    ;; Update the ecosystem configuration
    (var-set unit-acquisition-cost new-unit-cost)
    (var-set ecosystem-tribute-rate new-tribute-rate)
    (var-set individual-wisdom-ceiling new-scholar-limit)
    (var-set wisdom-repository-capacity new-repository-capacity)

    (ok true)))

