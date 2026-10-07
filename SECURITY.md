# Security Policy

## Scope

This repository defines the shared security baseline for a personal AWS Organization used for security engineering portfolio projects: the log archive, the organization trail, and organization-wide GuardDuty configuration. It is the defensive layer that records activity in every account, including accounts where attack simulations run.

Unlike the lab environments it observes, this repository is **not** intentionally vulnerable. Reports are welcome for anything that could weaken, disable, bypass, or tamper with organization-wide logging or threat detection, for example:

- Terraform that would allow log deletion, modification, or delivery to an unintended destination
- Overly broad bucket, topic, or role policies
- Gaps in logging coverage relative to what the documentation claims
- Committed information that should not be public, such as account identifiers or credentials

Out of scope: the intentionally vulnerable lab environments in other repositories, and findings that require access the repository owner already has.

## Design notes relevant to security

- All changes are applied manually by a human operator. This repository has no CI/CD access to AWS, and GitHub Actions is disabled.
- No account IDs, account names, or credentials are committed.
- Environment-specific values live in gitignored files, with committed `.example` templates.
- No real or third-party data is stored; the logs describe activity in infrastructure the owner fully controls.

## Reporting a vulnerability

Please use GitHub's **private vulnerability reporting**: open the **Security** tab of this repository and choose **Report a vulnerability**. Do not open a public issue for security reports.

This is a personal project maintained by one person, so responses are best effort.