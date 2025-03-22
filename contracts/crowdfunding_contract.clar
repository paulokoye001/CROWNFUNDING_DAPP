(define-map campaigns
  { campaign-id: uint }
  {
    creator: principal,
    goal: uint,
    deadline: uint,
    total-raised: uint,
    withdrawn: bool,
    milestone-count: uint,
    approved-milestones: uint
  }
)

(define-map contributions
  { campaign-id: uint, backer: principal }
  { amount: uint }
)

(define-map milestone-approvals
  { campaign-id: uint, milestone-index: uint, backer: principal }
  { approved: bool }
)

(define-data-var campaign-counter uint 0)

;; Create a new crowdfunding campaign
(define-public (create-campaign (goal uint) (deadline uint) (milestone-count uint))
  (let ((campaign-id (+ (var-get campaign-counter) 1)))
    (begin
      (map-insert campaigns
        { campaign-id: campaign-id }
        {
          creator: tx-sender,
          goal: goal,
          deadline: deadline,
          total-raised: 0,
          withdrawn: false,
          milestone-count: milestone-count,
          approved-milestones: 0
        }
      )
      (var-set campaign-counter campaign-id)
      (ok campaign-id)
    )
  )
)


;; Allow users to contribute STX to a campaign
(define-public (contribute (campaign-id uint))
  (let ((campaign (map-get? campaigns { campaign-id: campaign-id })))
    (match campaign
      campaign-data
      (if (and (> (get deadline campaign-data) block-height)
               (not (get withdrawn campaign-data)))
        (let ((amount (stx-get-transfer-amount)))
          (begin
            (map-set campaigns
              { campaign-id: campaign-id }
              (merge campaign-data { total-raised: (+ (get total-raised campaign-data) amount) })
            )
            (map-set contributions
              { campaign-id: campaign-id, backer: tx-sender }
              { amount: (+ (get amount (map-get? contributions { campaign-id: campaign-id, backer: tx-sender }) 0) amount) }
            )
            (ok amount)
          )
        )
        (err "Campaign not active or deadline passed")
      )
    )
  )
)


;; Backers vote to approve milestone releases
(define-public (approve-milestone (campaign-id uint) (milestone-index uint))
  (let ((campaign (map-get? campaigns { campaign-id: campaign-id }))
        (contribution (map-get? contributions { campaign-id: campaign-id, backer: tx-sender })))
    (match campaign
      campaign-data
      (if (and contribution
               (< milestone-index (get milestone-count campaign-data))
               (not (map-get? milestone-approvals { campaign-id: campaign-id, milestone-index: milestone-index, backer: tx-sender })))
        (begin
          (map-insert milestone-approvals { campaign-id: campaign-id, milestone-index: milestone-index, backer: tx-sender } { approved: true })
          (ok "Milestone approval recorded")
        )
        (err "Invalid milestone index or already approved")
      )
    )
  )
)

;; Withdraw funds if milestones are approved
(define-public (withdraw-funds (campaign-id uint))
  (let ((campaign (map-get? campaigns { campaign-id: campaign-id })))
    (match campaign
      campaign-data
      (if (and (is-eq (get creator campaign-data) tx-sender)
               (>= (get total-raised campaign-data) (get goal campaign-data))
               (< (get approved-milestones campaign-data) (get milestone-count campaign-data)))
        (let ((approved-votes (fold
                                (lambda (backer acc)
                                  (+ acc (if (get approved (map-get? milestone-approvals { campaign-id: campaign-id, milestone-index: (get approved-milestones campaign-data), backer: backer })) 1 0)))
                                0
                                (map-keys contributions))))
          (if (> approved-votes (/ (length (map-keys contributions)) 2))
            (begin
              (map-set campaigns
                { campaign-id: campaign-id }
                (merge campaign-data { approved-milestones: (+ (get approved-milestones campaign-data) 1) })
              )
              (stx-transfer (/ (get total-raised campaign-data) (get milestone-count campaign-data)) tx-sender)
              (ok "Milestone funds withdrawn")
            )
            (err "Milestone approval threshold not met")
          )
        )
        (err "Not authorized, goal not met, or all milestones already approved")
      )
    )
  )
)


