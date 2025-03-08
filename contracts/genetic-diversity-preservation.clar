;; Genetic Diversity Preservation Contract
;; Tracks and manages genetic diversity for species

(define-map genetic-profiles
  { species-id: uint }
  {
    diversity-index: uint,
    population-size: uint,
    mutation-rate: uint,
    critical-genes: (list 10 (string-utf8 32)),
    last-updated: uint
  }
)

(define-map diversity-thresholds
  { species-id: uint }
  {
    minimum-diversity: uint,
    optimal-diversity: uint,
    maximum-diversity: uint,
    alert-threshold: uint
  }
)

(define-map preservation-strategies
  { id: uint }
  {
    species-id: uint,
    strategy-type: (string-ascii 20),
    description: (string-utf8 128),
    effectiveness: uint,
    implementation-status: (string-ascii 20)
  }
)

(define-map diversity-alerts
  { id: uint }
  {
    species-id: uint,
    alert-type: (string-ascii 20),
    severity: uint,
    timestamp: uint,
    resolved: bool
  }
)

(define-data-var next-strategy-id uint u0)
(define-data-var next-alert-id uint u0)

;; Register a genetic profile for a species
(define-public (register-genetic-profile (species-id uint) (diversity-index uint) (population-size uint)
                                        (mutation-rate uint) (critical-genes (list 10 (string-utf8 32))))
  (ok (map-set genetic-profiles
    { species-id: species-id }
    {
      diversity-index: diversity-index,
      population-size: population-size,
      mutation-rate: mutation-rate,
      critical-genes: critical-genes,
      last-updated: block-height
    }
  ))
)

;; Set diversity thresholds for a species
(define-public (set-diversity-thresholds (species-id uint) (minimum-diversity uint)
                                        (optimal-diversity uint) (maximum-diversity uint) (alert-threshold uint))
  (ok (map-set diversity-thresholds
    { species-id: species-id }
    {
      minimum-diversity: minimum-diversity,
      optimal-diversity: optimal-diversity,
      maximum-diversity: maximum-diversity,
      alert-threshold: alert-threshold
    }
  ))
)

;; Update genetic diversity metrics
(define-public (update-diversity-metrics (species-id uint) (diversity-index uint) (population-size uint) (mutation-rate uint))
  (match (map-get? genetic-profiles { species-id: species-id })
    existing-profile
      (begin
        (map-set genetic-profiles
          { species-id: species-id }
          {
            diversity-index: diversity-index,
            population-size: population-size,
            mutation-rate: mutation-rate,
            critical-genes: (get critical-genes existing-profile),
            last-updated: block-height
          }
        )

        ;; Check if we need to create an alert
        (match (map-get? diversity-thresholds { species-id: species-id })
          thresholds
            (if (< diversity-index (get alert-threshold thresholds))
              (create-diversity-alert species-id "low-diversity" (- (get alert-threshold thresholds) diversity-index))
              (ok true))
          (ok true))
      )
    (err u404)
  )
)

;; Create a preservation strategy
(define-public (create-preservation-strategy (species-id uint) (strategy-type (string-ascii 20))
                                           (description (string-utf8 128)) (effectiveness uint))
  (let
    ((strategy-id (var-get next-strategy-id)))
    (var-set next-strategy-id (+ strategy-id u1))
    (ok (map-set preservation-strategies
      { id: strategy-id }
      {
        species-id: species-id,
        strategy-type: strategy-type,
        description: description,
        effectiveness: effectiveness,
        implementation-status: "planned"
      }
    ))
  )
)

;; Update strategy implementation status
(define-public (update-strategy-status (strategy-id uint) (implementation-status (string-ascii 20)))
  (match (map-get? preservation-strategies { id: strategy-id })
    strategy
      (ok (map-set preservation-strategies
        { id: strategy-id }
        (merge strategy { implementation-status: implementation-status })
      ))
    (err u404)
  )
)

;; Create a diversity alert
(define-private (create-diversity-alert (species-id uint) (alert-type (string-ascii 20)) (severity uint))
  (let
    ((alert-id (var-get next-alert-id)))
    (var-set next-alert-id (+ alert-id u1))
    (ok (map-set diversity-alerts
      { id: alert-id }
      {
        species-id: species-id,
        alert-type: alert-type,
        severity: severity,
        timestamp: block-height,
        resolved: false
      }
    ))
  )
)

;; Resolve a diversity alert
(define-public (resolve-alert (alert-id uint))
  (match (map-get? diversity-alerts { id: alert-id })
    alert
      (ok (map-set diversity-alerts
        { id: alert-id }
        (merge alert { resolved: true })
      ))
    (err u404)
  )
)

;; Get genetic profile
(define-read-only (get-genetic-profile (species-id uint))
  (map-get? genetic-profiles { species-id: species-id })
)

;; Get diversity thresholds
(define-read-only (get-diversity-thresholds (species-id uint))
  (map-get? diversity-thresholds { species-id: species-id })
)

;; Get preservation strategy
(define-read-only (get-preservation-strategy (strategy-id uint))
  (map-get? preservation-strategies { id: strategy-id })
)

;; Get diversity alert
(define-read-only (get-diversity-alert (alert-id uint))
  (map-get? diversity-alerts { id: alert-id })
)

;; Calculate diversity health score
(define-read-only (calculate-diversity-health (species-id uint))
  (match (map-get? genetic-profiles { species-id: species-id })
    profile
      (match (map-get? diversity-thresholds { species-id: species-id })
        thresholds
          (let
            ((diversity (get diversity-index profile))
             (optimal (get optimal-diversity thresholds))
             (minimum (get minimum-diversity thresholds))
             (maximum (get maximum-diversity thresholds)))

            ;; Calculate how close the diversity is to optimal (100 = perfect)
            (if (>= diversity optimal)
              (- u100 (/ (* (- diversity optimal) u100) (- maximum optimal)))
              (- u100 (/ (* (- optimal diversity) u100) (- optimal minimum)))))
        u0)
    u0
  )
)

;; Check if species diversity is in danger
(define-read-only (is-diversity-endangered (species-id uint))
  (match (map-get? genetic-profiles { species-id: species-id })
    profile
      (match (map-get? diversity-thresholds { species-id: species-id })
        thresholds
          (< (get diversity-index profile) (get minimum-diversity thresholds))
        false)
    false
  )
)

