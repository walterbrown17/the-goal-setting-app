;; Map to store each user's goal
(define-map user-goals
  {user: principal}  ;; key
  {target-date: uint, description: (string-ascii 100)}) ;; value

(define-constant err-empty-desc (err u100))
(define-constant err-invalid-date (err u101))

;; Public function to set a goal
(define-public (set-goal (target-date uint) (description (string-ascii 100)))
  (begin
    (asserts! (> target-date u0) err-invalid-date)
    (asserts! (> (len description) u0) err-empty-desc)
    (map-set user-goals {user: tx-sender} {target-date: target-date, description: description})
    (ok true)))

;; Read-only function to view the user's goal
(define-read-only (get-my-goal)
  (let ((entry (map-get? user-goals {user: tx-sender})))
    (ok (match entry
         val (some {target-date: (get target-date val), description: (get description val)})
         none))))
