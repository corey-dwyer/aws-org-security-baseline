# 0001: Manage the Organization-Wide Security Baseline in a Dedicated Repository

## Status
Accepted. This decision was first made from the consuming project's side in [aws-detection-as-code ADR 0011](https://github.com/corey-dwyer/aws-detection-as-code/blob/main/docs/decisions/0011-shared-security-baseline-in-dedicated-account-and-repository.md).

## Context
Organization-wide security services, such as the organization trail, the log archive, and GuardDuty's organization configuration, cover every account in the Organization, including accounts for projects that do not exist yet. Their configuration is shared infrastructure rather than part of any one project. Keeping it in a project's repository would tie every other project to that project's lifecycle, and tearing that project down would put organization-wide logging and detection at risk. Project repositories typically deploy through automated pipelines with narrowly scoped roles, whereas changes to the shared services affect who can see and stop activity across the whole Organization and warrant a more restricted change process. Organization structure (accounts, organizational units, trusted service access, delegated administrator registrations, and Identity Center assignments) is shared in the same way, but it changes rarely and is risky to automate from a project.

## Decision
The Organization's shared security baseline is managed in its own repository, this one. The shared security account's and the log archive account's resources are defined as separate Terraform root configurations, each with its own state. Organization structure is not defined in Terraform: it is configured manually in the management account by following a documented procedure kept in this repository (`docs/work-instructions/organization-setup.md`). Projects receive the baseline's outputs, such as bucket and topic identifiers, as input variables and do not read its state. Other repositories reference decisions recorded here by full link, never by number alone.

## Consequences
- Organization-wide logging and threat detection do not depend on any project, so a project can be torn down without affecting them.
- Changes to the shared services go through one repository with its own review and apply rules, separate from project pipelines.
- A project cannot be fully deployed until the baseline exists, and changes to the interface between the baseline and a project must be made in a coordinated order.
- Organization structure is not defined in code, so drift is not detected automatically and correctness depends on the documented procedure. It can be moved into Terraform in this repository later.
- The Organization gains one more repository to maintain, with its own governance, dependency updates, and documentation.