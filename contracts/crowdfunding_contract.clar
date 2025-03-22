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