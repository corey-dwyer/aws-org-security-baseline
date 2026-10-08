# Organization Setup Work Instruction

## 1. Purpose and scope

This work instruction configures the AWS Organization structure that the Terraform in this repository depends on but does not manage: member accounts, organizational units, trusted service access, delegated administrators, IAM Identity Center assignments, operator CLI profiles, and per-account budgets.

These settings apply across every project in the Organization, so they are deliberately not owned by any single project's code. They are configured manually by following this document, which keeps the procedure reviewable even though it is not automated. Moving them into Terraform in this repository is possible later. The decision behind this split is recorded in [aws-detection-as-code ADR 0011](https://github.com/corey-dwyer/aws-detection-as-code/blob/main/docs/decisions/0011-shared-security-baseline-in-dedicated-account-and-repository.md).

Use this document for the initial setup of the Organization's security baseline. Adding a later project account reuses sections 7, 10, 10, and 11.

## 2. Conventions

**No identifiers in this repository.** This repository is public. Account names, account IDs, email addresses, and organizational unit IDs never appear in it. Commands and instructions use the placeholders below; the operator keeps the real values in a private record outside the repository and substitutes them while working.

| Placeholder | Meaning |
|---|---|
| `<management-account-id>` | The Organization's management account |
| `<shared-security-account-id>` | Delegated administrator for CloudTrail and GuardDuty |
| `<log-archive-account-id>` | Holds the organization trail's bucket |
| `<project-tooling-account-id>` | A project's Terraform state, CI trust, and SIEM |
| `<project-target-account-id>` | A project's attack-simulation account |
| `<account-email>` | The root email address for the account being created |
| `<org-root-id>`, `<security-ou-id>`, `<projects-ou-id>` | The organization root and organizational unit IDs |
| `<identity-center-region>` | IAM Identity Center's home Region |
| `<workload-region>` | The Region where resources are created |
| `<sso-start-url>` | The IAM Identity Center access portal URL |
| `<alert-email>` | The email address that receives budget and anomaly alerts |
| `<org-monthly-budget>` | The monthly cost limit for the whole Organization, in USD |
| `<account-monthly-budget>` | The monthly cost limit for an individual account, in USD |

**Account roles.** Accounts are referred to by role: the shared security account, the log archive account, a project tooling account, and a project target account. The shared security account corresponds to the "Security Tooling" account in the AWS Security Reference Architecture; it is named differently here to avoid confusion with project tooling accounts. Organizational units are the Security OU and the projects OU.

**Step format.** Each section states **Why** the step exists, what to **Do**, and how to **Verify** the result. Console navigation can change over time; when it differs from this document, follow the intent of the step and treat the Verify checks as the definition of done.

**Corrections.** Differences found while following this document are fixed through a pull request, so the document always matches what was actually done.

## 3. Prerequisites

- The Organization has **all features** enabled. Trusted access, delegated administrators, centralized root access, and account renaming all require it. Verify in the AWS Organizations console under **Settings**.
- The management account's root user has MFA enabled, and the operator can access its root email inbox.
- IAM Identity Center is enabled in the management account in `<identity-center-region>`, and the operator's Identity Center user exists with its own password and MFA.
- The projects OU and the existing project account exist.
- A unique email address is ready for each account to be created. AWS requires a different address per account; plus-addressing on a single inbox (for example `name+role@example.com`) satisfies this.
- The operator's private record of real values is open.
- A Codespace for this repository is running, for the CLI steps in section 11.
- **Cost:** most steps here are free. Designating a GuardDuty delegated administrator automatically enables GuardDuty in that account in each Region where it is designated. That starts GuardDuty's 30-day free trial, after which usage is billed. Section 8.2 covers this before any designation happens.

## 4. Management-account access for the operator

**Why.** Organization-level tasks (creating accounts and organizational units, enabling trusted access, registering delegated administrators, and Identity Center assignments) can only be done from the management account. The operator's day-to-day Identity Center access has no assignment there, and the root user is reserved for tasks that require it. This section creates a dedicated permission set, `OrganizationAdministration`, assigned only to the management account. It is the only step in this work instruction that uses the root user: assigning access to the management account requires IAM administrative permissions there, which no Identity Center session has yet.

The permission set grants what this work instruction needs and nothing for running workloads:

| Policy | Type | Covers |
|---|---|---|
| `AWSOrganizationsFullAccess` | AWS managed | Accounts, organizational units, trusted access, delegated administrator registration |
| `AWSSSOMasterAccountAdministrator` | AWS managed | Identity Center permission sets and account assignments |
| `AWSCloudTrail_ReadOnlyAccess` | AWS managed | Read access the CloudTrail console needs to display organization settings |
| `AmazonGuardDutyReadOnlyAccess` | AWS managed | Read access the GuardDuty console needs to display organization settings |
| `AWSBillingReadOnlyAccess` | AWS managed | Read access to billing data, needed by the Budgets and Cost Anomaly Detection consoles |
| Inline policy (below) | Custom | CloudTrail and GuardDuty delegated administrators, centralized root access, account rename, budgets, and cost anomaly detection |

An identity that administers Organizations and Identity Center can grant itself further access, so this permission set does not contain its holder. Its purpose is to keep routine administrator access out of the management account, make every management-account session a separate and deliberate sign-in, and limit the impact of mistakes.

**Do** (signed in as the management account's root user, with MFA):

1. Open IAM Identity Center in `<identity-center-region>`.
2. Choose **Permission sets**, then **Create permission set**, then **Custom permission set**.
3. Attach the AWS managed policies `AWSOrganizationsFullAccess`, `AWSSSOMasterAccountAdministrator`, `AWSCloudTrail_ReadOnlyAccess`, `AmazonGuardDutyReadOnlyAccess`, and `AWSBillingReadOnlyAccess`. If any name does not appear, stop and check the current AWS managed policy list before continuing.
4. Add the inline policy below.
5. Name the permission set `OrganizationAdministration`, add a description, and set the session duration to 1 hour.
6. Choose **AWS accounts**, select the management account, choose **Assign users or groups**, select the operator's user, select `OrganizationAdministration`, and submit.
7. Sign out of the root user.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudTrailDelegatedAdministrator",
      "Effect": "Allow",
      "Action": [
        "cloudtrail:RegisterOrganizationDelegatedAdmin",
        "cloudtrail:DeregisterOrganizationDelegatedAdmin",
        "iam:GetRole"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudTrailServiceLinkedRoles",
      "Effect": "Allow",
      "Action": "iam:CreateServiceLinkedRole",
      "Resource": "*",
      "Condition": {
        "StringLike": {
          "iam:AWSServiceName": [
            "cloudtrail.amazonaws.com",
            "context.cloudtrail.amazonaws.com"
          ]
        }
      }
    },
    {
      "Sid": "GuardDutyDelegatedAdministrator",
      "Effect": "Allow",
      "Action": [
        "guardduty:EnableOrganizationAdminAccount",
        "guardduty:DisableOrganizationAdminAccount",
        "guardduty:ListOrganizationAdminAccounts"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CentralizedRootAccess",
      "Effect": "Allow",
      "Action": [
        "iam:EnableOrganizationsRootCredentialsManagement",
        "iam:EnableOrganizationsRootSessions",
        "iam:ListOrganizationsFeatures",
        "iam:GetAccountSummary",
        "iam:GetAccessKeyLastUsed",
        "iam:GetLoginProfile",
        "iam:GetUser",
        "iam:ListAccessKeys",
        "iam:ListMFADevices",
        "iam:ListSigningCertificates",
        "sts:AssumeRoot"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AccountRename",
      "Effect": "Allow",
      "Action": [
        "account:PutAccountName",
        "account:GetAccountInformation"
      ],
      "Resource": "*"
    },
        {
      "Sid": "BudgetsAndCostAnomalyDetection",
      "Effect": "Allow",
      "Action": [
        "budgets:ViewBudget",
        "budgets:ModifyBudget",
        "ce:GetAnomalyMonitors",
        "ce:CreateAnomalyMonitor",
        "ce:UpdateAnomalyMonitor",
        "ce:GetAnomalySubscriptions",
        "ce:CreateAnomalySubscription",
        "ce:UpdateAnomalySubscription",
        "ce:GetAnomalies"
      ],
      "Resource": "*"
    }
  ]
}
```

**Verify:**

- The access portal lists the management account with `OrganizationAdministration` only, and project accounts still show `AdministratorAccess`.
- Signed in to the management account through `OrganizationAdministration`, the AWS Organizations console lists the organization's accounts.
- In the same session, the Amazon EC2 console reports that access is denied. This confirms the permission set is not general administrator access.

## 5. Root credentials for member accounts

**Why.** Each member account has a root user with unrestricted access to that account, and by default anyone with access to the account's root email inbox can reset its password. Centralized root access removes that path: member accounts can no longer sign in as root or recover root credentials, and accounts created afterwards have no root credentials at all. This matters most for the project target account, where attack simulations deliberately behave like an adversary. When a root-only task is genuinely needed, the management account can open a short-lived privileged session scoped to that task instead, for example to recover a root password or to delete a bucket or queue policy that denies all access.

This section runs before section 7 so that new accounts are created without root credentials. It must be done as the operator through `OrganizationAdministration`, not as the root user: AWS does not allow root user credentials to start privileged sessions.

No delegated administrator is registered for IAM. Delegating would allow a second account to delete or restore root credentials for every member account; keeping the capability in the management account alone limits it to the most protected account.

**Do** (signed in to the management account through `OrganizationAdministration`):

1. Open the IAM console and choose **Root access management**. If it reports that the feature is disabled, first enable trusted access for AWS Identity and Access Management in the AWS Organizations console under **Services**, then return.
2. Choose **Enable**, and select both capabilities: **Root credentials management** and **Privileged root actions in member accounts**.
3. Leave **Delegated administrator** empty, and choose **Enable**.
4. In the member account list, check the root user credential status of the existing project account. If any root credential is present (password, access keys, signing certificates, or MFA device), select the account, choose **Take privileged action**, then **Delete root credentials**.

**Verify:**

- **Root access management** shows both capabilities enabled and no delegated administrator.
- The existing project account shows no root user credentials.
- The management account's own root user is unaffected and still has MFA enabled. Centralized root access applies only to member accounts.
- Accounts created in section 7 are checked for root credentials in section 12.

## 6. Organizational units

**Why.** Organizational units group accounts by the guardrails they need. The Security OU holds the shared accounts that store and analyze organization-wide security data, and can later carry stricter service control policies than project accounts. Project target accounts must allow simulated attacks, so they stay in the projects OU.

**Do** (signed in to the management account through `OrganizationAdministration`):

1. Open the AWS Organizations console and choose **AWS accounts**.
2. Select the organization root, choose **Actions**, then **Create new** under organizational unit, and name it `Security`.
3. Confirm the projects OU already exists under the root.

**Verify:**

- The root contains exactly two organizational units: the Security OU and the projects OU.
- Record `<security-ou-id>` and `<projects-ou-id>` in the private record.

## 7. Create member accounts

**Why.** This step creates the shared security account, the log archive account, and the project target account. Accounts created now have no root credentials, because section 5 is complete.

Each new account has these settings, chosen deliberately rather than left to defaults:

| Setting | Value | Reason |
|---|---|---|
| IAM user and role access to billing | Allowed | The account has no root credentials, so without this setting nothing could view its billing information. Access is still limited by IAM permissions. |
| Access role name | `OrganizationAccountAccessRole` (default) | An administrator role trusted by the management account. No principal in the management account is currently permitted to assume it: `OrganizationAdministration` does not grant `sts:AssumeRole`, and the root user cannot assume roles. It remains as a dormant recovery path if IAM Identity Center becomes unavailable. Any use of it appears in the organization trail and is worth alerting on. |
| Destination | Organization root, then moved | New accounts are always created at the root. |

Account creation is effectively permanent: AWS discourages creating temporary accounts, and account closures are subject to a quota. Check each account's name and email address against the private record before submitting.

**Do** (signed in to the management account through `OrganizationAdministration`), for each of the log archive account, the shared security account, and the project target account:

1. In the AWS Organizations console, choose **AWS accounts**, then **Add an AWS account**, then **Create an AWS account**.
2. Enter the account name and `<account-email>` from the private record.
3. Leave the IAM role name as `OrganizationAccountAccessRole`.
4. Submit, and wait until the account's status is **Active**. Creation runs in the background and can take several minutes.
5. Select the account, choose **Actions**, then **Move**, and move it to its organizational unit: the Security OU for the log archive and shared security accounts, and the projects OU for the project target account.
6. Record the account ID in the private record.

**Verify:**

- The Security OU contains the log archive account and the shared security account, and nothing else.
- The projects OU contains the existing project account and the project target account.
- No new account remains directly under the root.
- Each account's root email inbox received AWS's welcome email, which confirms the address is valid.

## 8. Trusted access and delegated administrators

**Why.** The organization trail and GuardDuty's organization configuration are administered from the shared security account rather than the management account, which keeps day-to-day security administration out of the most privileged account. Only the management account can designate a delegated administrator, so this designation is part of the organization setup, while the trail and GuardDuty settings themselves are managed with Terraform in this repository.

### 8.1 CloudTrail

CloudTrail has one delegated administrator for the whole organization. It must be registered through CloudTrail, not through AWS Organizations: registering through CloudTrail also creates the service-linked roles CloudTrail needs in the management account. Organization trails created by the delegated administrator remain owned by the management account, so changing the delegated administrator later does not delete or alter them.

**Do** (signed in to the management account through `OrganizationAdministration`):

1. Open the CloudTrail console and choose **Settings**.
2. Under **Organization delegated administrators**, choose **Register administrator**, enter `<shared-security-account-id>`, and confirm.
3. If registration reports that trusted access is not enabled, enable trusted access for AWS CloudTrail in the AWS Organizations console under **Services**, then repeat step 2.

**Verify:**

- CloudTrail **Settings** lists `<shared-security-account-id>` as the only organization delegated administrator.
- In the AWS Organizations console under **Services**, AWS CloudTrail shows trusted access enabled.

### 8.2 GuardDuty

GuardDuty is a Regional service: its delegated administrator is designated separately in each Region, and must be the same account in every Region. The Regions in scope are defined once, as a variable in this repository's `security-services` Terraform configuration. Designate the delegated administrator in each Region in that list; if the list is not yet defined, designate it in `<workload-region>` only and repeat this section when Regions are added.

Designating the delegated administrator automatically enables GuardDuty in the shared security account in that Region, which starts GuardDuty's 30-day free trial for that account and Region. Usage is billed after the trial.

GuardDuty must not be enabled in the management account from this console. Whether the management account is monitored is configured from the delegated administrator, through Terraform.

**Do** (signed in to the management account through `OrganizationAdministration`), in each Region in scope:

1. Open the GuardDuty console and select the Region.
2. If the console shows a welcome page, use only the **Delegated administrator** field on it. Do not choose any option that enables GuardDuty for the management account.
3. Enter `<shared-security-account-id>` and choose **Delegate**.

**Verify**, in each Region in scope:

- The GuardDuty console's delegated administrator setting shows `<shared-security-account-id>`.
- In the AWS Organizations console under **Services**, Amazon GuardDuty shows trusted access enabled.
- GuardDuty is not enabled in the management account. Signed in through `OrganizationAdministration`, the GuardDuty console in that Region does not show an active detector for the management account.

## 9. IAM Identity Center account assignments

**Why.** The operator needs access to each new account: to apply Terraform in the shared security and log archive accounts, and to work in the project target account. The existing `AdministratorAccess` permission set is assigned to each, consistent with the rest of the Organization's single-operator access model.

Administrator access is broader than routine work needs, but with a single operator, splitting permission sets would not separate duties: the same person would hold every permission set. Log integrity is protected instead by resource-level controls on the log archive, and by service control policies on the Security OU, which restrict every principal in those accounts, including administrators. Narrower permission sets remain possible future hardening.

**Do** (signed in to the management account through `OrganizationAdministration`):

1. Open IAM Identity Center in `<identity-center-region>` and choose **AWS accounts**.
2. Select the shared security account, the log archive account, and the project target account.
3. Choose **Assign users or groups**, select the operator's user, select `AdministratorAccess`, and submit.

**Verify:**

- After signing out and back in, the access portal lists the shared security, log archive, and project target accounts, each with `AdministratorAccess`.
- The management account still shows `OrganizationAdministration` only.
- Signing in to each new account through the portal shows the account ID recorded for it in section 7.

## 10. CLI profiles

**Why.** Terraform and the AWS CLI authenticate through IAM Identity Center profiles in `~/.aws/config`. Profile names describe account roles rather than account names, so they can appear in this repository, in commands, and in committed `backend.hcl.example` files.

The management account uses its own SSO session. A single `aws sso login` lets every profile in that session obtain credentials, so sharing a session would make management-account credentials available whenever the operator signs in for routine work. With a separate session, management-account access from the CLI requires its own deliberate sign-in.

The profile configuration lives in the development environment and is lost when a Codespace is deleted. Keep a completed copy of the configuration below in the private record, and add it to each new Codespace.

**Do:** add the following to `~/.aws/config`, replacing placeholders with values from the private record, and `<project>` with the project's name.

```ini
[sso-session operator]
sso_start_url = <sso-start-url>
sso_region = <identity-center-region>
sso_registration_scopes = sso:account:access

[sso-session management]
sso_start_url = <sso-start-url>
sso_region = <identity-center-region>
sso_registration_scopes = sso:account:access

[profile org-management]
sso_session = management
sso_account_id = <management-account-id>
sso_role_name = OrganizationAdministration
region = <workload-region>

[profile shared-security]
sso_session = operator
sso_account_id = <shared-security-account-id>
sso_role_name = AdministratorAccess
region = <workload-region>

[profile log-archive]
sso_session = operator
sso_account_id = <log-archive-account-id>
sso_role_name = AdministratorAccess
region = <workload-region>

[profile <project>-tooling]
sso_session = operator
sso_account_id = <project-tooling-account-id>
sso_role_name = AdministratorAccess
region = <workload-region>

[profile <project>-target]
sso_session = operator
sso_account_id = <project-target-account-id>
sso_role_name = AdministratorAccess
region = <workload-region>
```

**Verify:**

1. Run `aws sso login --sso-session operator` and complete the browser sign-in.
2. For each of `shared-security`, `log-archive`, `<project>-tooling`, and `<project>-target`, run `aws sts get-caller-identity --profile <profile>` and confirm the `Account` value matches the private record for that role.
3. Run `aws sts get-caller-identity --profile org-management`. It must fail with an expired or missing token error, because the management session has not been signed in. This confirms the two sessions are separate.
4. Run `aws sso login --sso-session management`, repeat the `org-management` check, and confirm the `Account` value is the management account and the role in the `Arn` contains `OrganizationAdministration`.
5. Run `aws sso logout` when management-account work is finished.

## 11. Budgets and cost monitoring

**Why.** Cost alerts are a detective control, and like logs they are kept out of reach of the accounts they monitor. Budgets and anomaly detection are created centrally in the management account, so no member account, including a project target account used for attack simulation, can view, change, or delete them. An organization-wide budget sets the overall spending limit, including the shared baseline's own costs, while per-account budgets show which account caused a change.

**Do** (signed in to the management account through `OrganizationAdministration`):

1. Open **Billing and Cost Management**, choose **Budgets**, then **Create budget**, using a customized cost budget each time.
2. Create the organization budget: name `organization-monthly`, a monthly period, a fixed amount of `<org-monthly-budget>`, and no account filter. Add email alerts to `<alert-email>` at 50%, 80%, and 100% of actual cost, and at 100% of forecasted cost.
3. For each member account, create a budget named after its role, for example `shared-security-monthly`, with a monthly period, a fixed amount of `<account-monthly-budget>` from the private record, and a **Linked account** filter set to that account only. Add email alerts to `<alert-email>` at 80% and 100% of actual cost, and at 100% of forecasted cost.
4. Open **Cost Anomaly Detection** and create a monitor: choose an AWS managed monitor with the **Linked account** dimension, named `organization-linked-accounts`. It tracks every member account, including accounts added later.
5. Create an alert subscription for that monitor: a daily summary sent to `<alert-email>`, with the threshold from the private record.

**Verify:**

- **Budgets** lists `organization-monthly` and one budget per member account, and each per-account budget's filter shows the account ID recorded for that role.
- **Cost Anomaly Detection** shows `organization-linked-accounts` as active, with the daily summary subscription attached. New monitors can take up to 24 hours to start detecting anomalies.
- Signed in to the project target account through `AdministratorAccess`, the Budgets console shows none of these budgets. This confirms member accounts cannot see or change them.

## 12. Final verification

**Why.** Each section verifies its own result. This final pass checks the finished structure as a whole, completes checks that were deferred until all accounts existed, and repeats the negative tests that confirm access is no broader than intended. It uses read-only commands only.

**Do:** sign in with `aws sso login --sso-session management`, then work through the checks below. Sign out with `aws sso logout` when finished.

**Organization structure:**

- `aws organizations list-accounts-for-parent --parent-id <security-ou-id> --profile org-management` lists exactly the shared security account and the log archive account.
- `aws organizations list-accounts-for-parent --parent-id <projects-ou-id> --profile org-management` lists exactly the project tooling account and the project target account.
- `aws organizations list-accounts-for-parent --parent-id <org-root-id> --profile org-management` lists only the management account.

**Trusted access and delegated administrators:**

- `aws organizations list-aws-service-access-for-organization --profile org-management` includes AWS CloudTrail, Amazon GuardDuty, AWS Identity and Access Management, AWS Account Management, and IAM Identity Center. Any other service listed should be explainable.
- `aws organizations list-delegated-administrators --profile org-management` lists only the shared security account, and `aws organizations list-delegated-services-for-account --account-id <shared-security-account-id> --profile org-management` shows it is delegated administrator for CloudTrail and GuardDuty only.

**Root credentials** (the check deferred from section 5):

- In the IAM console under **Root access management**, signed in through `OrganizationAdministration`, every member account, including those created in section 7, shows no root user credentials.

**Access:**

- The access portal shows `OrganizationAdministration` for the management account only, and `AdministratorAccess` for each member account.
- `aws sts get-caller-identity` with each profile from section 10 returns the account ID recorded for that role.

**Negative tests:**

- In the management account through `OrganizationAdministration`, the Amazon EC2 console reports that access is denied (section 4).
- GuardDuty is not enabled in the management account in any Region in scope (section 8.2).
- In the project target account, the Budgets console shows none of the central budgets (section 11).
- Before signing in to the management session, `aws sts get-caller-identity --profile org-management` fails (section 10).

**Records:**

- The private record contains every account ID, organizational unit ID, and the date GuardDuty was designated in each Region, which marks the start of its 30-day free trial.
- Any difference between this document and what was actually done has been noted for a correction pull request.