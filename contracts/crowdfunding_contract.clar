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