;; Species Development Trajectory Contract
;; Tracks and manages the development paths of different species across cosmic evolution

(define-map species
  { id: uint }
  {
    name: (string-utf8 64),
    origin-planet: (string-utf8 64),
    current-epoch: uint,
    intelligence-level: uint,
    technological-level: uint,
    registered-by: principal
  }
)

(define-map trajectories
  { species-id: uint }
  {
    target-intelligence: uint,
    target-technology: uint,
    estimated-epochs: uint,
    optimization-level: uint,
    last-updated: uint
  }
)

(define-map progress-updates
  { id: uint }
  {
    species-id: uint,
    epoch: uint,
    intelligence-change: int,
    technology-change: int,
    notes: (string-utf8 128)
  }
)

(define-data-var next-species-id uint u0)
(define-data-var next-update-id uint u0)

;; Register a new species
(define-public (register-species (name (string-utf8 64)) (origin-planet (string-utf8 64)) (intelligence-level uint) (technological-level uint))
  (let
    ((species-id (var-get next-species-id)))
    (var-set next-species-id (+ species-id u1))
    (ok (map-set species
      { id: species-id }
      {
        name: name,
        origin-planet: origin-planet,
        current-epoch: u1,
        intelligence-level: intelligence-level,
        technological-level: technological-level,
        registered-by: tx-sender
      }
    ))
  )
)

;; Set development trajectory for a species
(define-public (set-trajectory (species-id uint) (target-intelligence uint) (target-technology uint) (estimated-epochs uint) (optimization-level uint))
  (match (map-get? species { id: species-id })
    existing-species
      (ok (map-set trajectories
        { species-id: species-id }
        {
          target-intelligence: target-intelligence,
          target-technology: target-technology,
          estimated-epochs: estimated-epochs,
          optimization-level: optimization-level,
          last-updated: block-height
        }
      ))
    (err u404)
  )
)

;; Record a progress update for a species
(define-public (record-progress (species-id uint) (intelligence-change int) (technology-change int) (notes (string-utf8 128)))
  (match (map-get? species { id: species-id })
    existing-species
      (let
        ((update-id (var-get next-update-id))
         (new-epoch (+ (get current-epoch existing-species) u1))
         (new-intelligence (+ (to-int (get intelligence-level existing-species)) intelligence-change))
         (new-technology (+ (to-int (get technological-level existing-species)) technology-change)))

        ;; Ensure values don't go below zero
        (asserts! (>= new-intelligence 0) (err u400))
        (asserts! (>= new-technology 0) (err u400))

        ;; Update species with new values
        (map-set species
          { id: species-id }
          {
            name: (get name existing-species),
            origin-planet: (get origin-planet existing-species),
            current-epoch: new-epoch,
            intelligence-level: (to-uint new-intelligence),
            technological-level: (to-uint new-technology),
            registered-by: (get registered-by existing-species)
          }
        )

        ;; Record the update
        (var-set next-update-id (+ update-id u1))
        (ok (map-set progress-updates
          { id: update-id }
          {
            species-id: species-id,
            epoch: new-epoch,
            intelligence-change: intelligence-change,
            technology-change: technology-change,
            notes: notes
          }
        ))
      )
    (err u404)
  )
)

;; Calculate development progress percentage
(define-read-only (calculate-progress (species-id uint))
  (match (map-get? species { id: species-id })
    existing-species
      (match (map-get? trajectories { species-id: species-id })
        trajectory
          (let
            ((intelligence-progress (/ (* (get intelligence-level existing-species) u100) (get target-intelligence trajectory)))
             (technology-progress (/ (* (get technological-level existing-species) u100) (get target-technology trajectory)))
             (epoch-progress (/ (* (get current-epoch existing-species) u100) (get estimated-epochs trajectory))))
            {
              intelligence-progress: intelligence-progress,
              technology-progress: technology-progress,
              epoch-progress: epoch-progress,
              overall-progress: (/ (+ intelligence-progress technology-progress) u2)
            })
        { intelligence-progress: u0, technology-progress: u0, epoch-progress: u0, overall-progress: u0 })
    { intelligence-progress: u0, technology-progress: u0, epoch-progress: u0, overall-progress: u0 }
  )
)

;; Get species details
(define-read-only (get-species (species-id uint))
  (map-get? species { id: species-id })
)

;; Get trajectory details
(define-read-only (get-trajectory (species-id uint))
  (map-get? trajectories { species-id: species-id })
)

;; Get progress update
(define-read-only (get-progress-update (update-id uint))
  (map-get? progress-updates { id: update-id })
)

;; Check if species has reached target development
(define-read-only (has-reached-target (species-id uint))
  (match (map-get? species { id: species-id })
    existing-species
      (match (map-get? trajectories { species-id: species-id })
        trajectory
          (and
            (>= (get intelligence-level existing-species) (get target-intelligence trajectory))
            (>= (get technological-level existing-species) (get target-technology trajectory)))
        false)
    false
  )
)

