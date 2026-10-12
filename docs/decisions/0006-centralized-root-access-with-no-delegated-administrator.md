# 0006: Centralize Root Access Management in the Management Account, with No Delegated Administrator

## Status
Accepted.

## Context
Every member account has a root user with unrestricted access to that account, and by default anyone who can read the root email inbox can reset its password. Each account's root credentials (password, MFA device, access keys, signing certificates) are one more set of secrets to protect, and each root email address is one more recovery path. The risk is greatest in the project target account, where attack simulations deliberately behave like an adversary. AWS Organizations offers centralized root access management, which removes root credentials from member accounts, prevents root sign-in and password recovery for them, and lets the management account open short-lived, task-scoped privileged sessions when a task genuinely requires root. It has two capabilities, root credentials management and privileged root actions, and its administration can optionally be delegated to another account. Alternatives were to keep per-account root credentials protected by MFA, which leaves many secrets and email recovery paths to defend, and to enable credentials management without privileged sessions, which leaves root-only tasks with no route.

## Decision
Centralized root access management is enabled with both capabilities, before further member accounts are created, so that new accounts never have root credentials. Existing root credentials in member accounts are removed. No delegated administrator is registered for IAM, so only the management account can manage member-account root credentials or start privileged sessions, because delegating would let a second account delete or restore them for every member account. A genuine root-only task is done in a short-lived privileged session scoped to that task, opened from the management account by the operator through the permission set described in 0005. AWS does not allow root user credentials to start these sessions, so the management account's own root user is not part of this path. That root user is unaffected by centralized root access and keeps its MFA protection.

## Consequences
- Member accounts have no root credentials to steal, phish, or recover through an email inbox, including the account where attacks are simulated.
- The authority to delete or restore root credentials across all member accounts is held by the management account alone, which already controls the Organization, so this concentrates the authority and does not add a second place that holds it.
- A root-only task is a deliberate privileged session from the management account, which is more steps than signing in as root.
- The path to those sessions depends on the management account and Identity Center being available. The management account's root user remains as the last resort.
- Because member accounts have no root user, IAM access to billing information is allowed on them, since nobody could turn it on later.
- Adding an account later follows the same rule: it is created after this setting is enabled, so it has no root credentials from the start.