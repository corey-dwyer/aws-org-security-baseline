# 0002: Give the Shared Baseline Repository No CI Access to AWS

## Status
Accepted.

## Context
This repository's configurations control the Organization's organization trail, its log archive, and its GuardDuty organization configuration. Whoever can change them can stop logging or detection for every account in the Organization. A pipeline that applies Terraform needs credentials with that authority, and a pipeline's credentials are reachable through everything that can alter its workflow: a merged pull request, a compromised maintainer account, or a compromised third-party action. The consuming project accepts this trade-off for its own lab infrastructure, where CI is limited to a narrow, separately scoped role and cannot modify its own permissions ([aws-detection-as-code ADR 0006](https://github.com/corey-dwyer/aws-detection-as-code/blob/main/docs/decisions/0006-manual-apply-for-privileged-terraform.md)). The shared services have a larger blast radius than any single project, and this repository changes rarely, so the speed CI would add is worth little. Alternatives considered were a plan-only CI role with manual apply, and CI apply behind a required approval.

## Decision
No workflow in this repository has access to AWS. GitHub Actions is disabled for the repository, so a workflow added through a merged pull request cannot run, and re-enabling it is a deliberate settings change. The control that does not depend on that setting is that no account in the Organization trusts GitHub as an identity provider for this repository: no shared account has a GitHub OIDC provider or a role that GitHub can assume. Every plan and apply is run by a human operator, in an interactive session obtained through IAM Identity Center.

## Consequences
- A change merged to this repository cannot alter the shared services by itself. A change takes effect only when an operator applies it.
- Re-enabling GitHub Actions alone grants no AWS access, because the trust would also have to be created in AWS.
- Pull requests receive no automated plan. Reviewers rely on the configuration diff and on the operator's own plan output, and formatting and validation checks depend on the operator running them.
- Drift between the code and the real resources is not detected automatically.
- The path to the shared services runs through the operator's identity and workstation instead of a pipeline, so protecting that identity (the Identity Center sign-in, short-lived sessions, signed commits) carries the weight a pipeline's controls would otherwise carry.
- Adding CI later requires a new decision that supersedes this one, and a plan-only role is the likely starting point.