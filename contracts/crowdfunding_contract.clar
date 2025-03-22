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