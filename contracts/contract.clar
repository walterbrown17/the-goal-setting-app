;; Goal Setting App Contract
;; Set and track personal goals on the blockchain with immutable progress tracking

;; Define goal structure
(define-map goals 
  {goal-id: uint} 
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 300),
    target-value: uint,
    current-progress: uint,
    deadline: uint,
    category: (string-ascii 50),
    is-completed: bool,
    created-at: uint,
    completed-at: (optional uint)
  })

;; Track goal counter and user goals
(define-data-var goal-counter uint u0)
(define-map user-goals principal (list 20 uint))

;; Progress tracking for each goal
(define-map goal-progress 
  {goal-id: uint, update-id: uint}
  {
    progress-amount: uint,
    notes: (string-ascii 200),
    updated-at: uint,
    updated-by: principal
  })

(define-map goal-update-counter uint uint)

;; Constants for error handling
(define-constant err-invalid-goal-id (err u300))
(define-constant err-goal-not-found (err u301))
(define-constant err-unauthorized (err u302))
(define-constant err-invalid-deadline (err u303))
(define-constant err-invalid-input (err u304))
(define-constant err-goal-already-completed (err u305))
(define-constant err-invalid-progress (err u306))

;; Function 1: Create Goal
;; Allows users to create and store personal goals on the blockchain
(define-public (create-goal 
  (title (string-ascii 100))
  (description (string-ascii 300))
  (target-value uint)
  (deadline uint)
  (category (string-ascii 50)))
  (let (
    (new-goal-id (+ (var-get goal-counter) u1))
    (current-block-height block-height)
  )
  (begin
    ;; Validate inputs
    (asserts! (> (len title) u0) err-invalid-input)
    (asserts! (> target-value u0) err-invalid-input)
    (asserts! (> deadline current-block-height) err-invalid-deadline)
    
    ;; Create the goal
    (map-set goals 
      {goal-id: new-goal-id}
      {
        creator: tx-sender,
        title: title,
        description: description,
        target-value: target-value,
        current-progress: u0,
        deadline: deadline,
        category: category,
        is-completed: false,
        created-at: current-block-height,
        completed-at: none
      })
    
    ;; Initialize progress counter for this goal
    (map-set goal-update-counter new-goal-id u0)
    
    ;; Update user's goal list
    (let ((current-goals (default-to (list) (map-get? user-goals tx-sender))))
      (map-set user-goals tx-sender (unwrap! (as-max-len? (append current-goals new-goal-id) u20) err-invalid-input)))
    
    ;; Increment counter
    (var-set goal-counter new-goal-id)
    
    ;; Print goal creation notification
    (print {
      action: "goal-created",
      goal-id: new-goal-id,
      creator: tx-sender,
      title: title,
      target-value: target-value,
      deadline: deadline
    })
    
    (ok new-goal-id))))

;; Function 2: Update Goal Progress
;; Allows users to update progress on their goals and mark completion
(define-public (update-progress 
  (goal-id uint)
  (progress-amount uint)
  (notes (string-ascii 200)))
  (let (
    (goal-data (unwrap! (map-get? goals {goal-id: goal-id}) err-goal-not-found))
    (current-update-count (default-to u0 (map-get? goal-update-counter goal-id)))
    (new-update-id (+ current-update-count u1))
    (new-total-progress (+ (get current-progress goal-data) progress-amount))
    (target (get target-value goal-data))
    (is-now-completed (>= new-total-progress target))
  )
  (begin
    ;; Validate authorization
    (asserts! (is-eq tx-sender (get creator goal-data)) err-unauthorized)
    (asserts! (not (get is-completed goal-data)) err-goal-already-completed)
    (asserts! (> progress-amount u0) err-invalid-progress)
    
    ;; Record the progress update
    (map-set goal-progress
      {goal-id: goal-id, update-id: new-update-id}
      {
        progress-amount: progress-amount,
        notes: notes,
        updated-at: block-height,
        updated-by: tx-sender
      })
    
    ;; Update the goal's current progress
    (map-set goals 
      {goal-id: goal-id}
      (merge goal-data {
        current-progress: new-total-progress,
        is-completed: is-now-completed,
        completed-at: (if is-now-completed (some block-height) none)
      }))
    
    ;; Update progress counter
    (map-set goal-update-counter goal-id new-update-id)
    
    ;; Print progress update notification
    (print {
      action: "progress-updated",
      goal-id: goal-id,
      progress-amount: progress-amount,
      total-progress: new-total-progress,
      target-value: target,
      is-completed: is-now-completed,
      notes: notes
    })
    
    (ok {
      goal-id: goal-id,
      new-progress: new-total-progress,
      is-completed: is-now-completed,
      progress-percentage: (/ (* new-total-progress u100) target)
    }))))

;; Helper function: Get goal details
(define-read-only (get-goal (goal-id uint))
  (let ((goal-data (map-get? goals {goal-id: goal-id})))
    (match goal-data
      goal-info (ok (some goal-info))
      (ok none))))

;; Helper function: Get user's goals
(define-read-only (get-user-goals (user principal))
  (ok (default-to (list) (map-get? user-goals user))))

;; Helper function: Get goal progress history
(define-read-only (get-goal-progress-history (goal-id uint))
  (let ((update-count (default-to u0 (map-get? goal-update-counter goal-id))))
    (ok {
      total-updates: update-count,
      goal-id: goal-id
    })))

;; Helper function: Get specific progress update
(define-read-only (get-progress-update (goal-id uint) (update-id uint))
  (ok (map-get? goal-progress {goal-id: goal-id, update-id: update-id})))

;; Helper function: Get total goals count
(define-read-only (get-total-goals)
  (ok (var-get goal-counter)))

;; Helper function: Check if goal exists
(define-read-only (goal-exists (goal-id uint))
  (ok (is-some (map-get? goals {goal-id: goal-id}))))