# 0009: Record S3 Data Events Organization-Wide, Excluding the Log Archive Bucket

## Status
Accepted. Builds on [0007](0007-log-archive-bucket-protection.md) and [0008](0008-organization-trail-managed-from-management-account.md). Serves the detection scope in [aws-detection-as-code ADR 0008](https://github.com/corey-dwyer/aws-detection-as-code/blob/main/docs/decisions/0008-scope-to-attack-v19-iaas-matrix.md).

## Context
CloudTrail records management events by default but not object-level S3 activity, which is a separate category called data events and is billed per event. Detecting techniques such as data from cloud storage (T1530) and data destruction (T1485) needs that object-level record. Options were: management events only, data events for a named list of buckets, data events for every bucket, or every bucket except the log archive. A named list misses buckets created later in any account and needs an edit for each new one. Recording every bucket, including the log archive, creates a feedback loop: reading archived logs generates data events, which are written to the same bucket and must be read in turn. The same loop would apply to the replay pipeline that reads the archive.

## Decision
The organization trail records all management events, and S3 data events for every bucket in every account, using advanced event selectors, with one exclusion: objects in the log archive bucket. The exclusion matches the bucket's ARN followed by a trailing slash, so it covers only that bucket and not others whose names share a prefix. The trail is the single configuration for this, defined in the management-account configuration (0008). Narrower options, such as excluding only reads from the log archive, were rejected because the documentation does not show whether the trail's own deliveries to the bucket would then be recorded and re-trigger the loop, and an unbounded loop costs money.

## Consequences
- Buckets created later, in existing or new accounts, are covered automatically, with no per-bucket edit.
- Cost scales with object-level activity across the Organization, since data events are billed per event. At this project's scale it should be small, and the budget and cost anomaly detection watch it. It would need revisiting if the Organization grows.
- Object-level changes inside the log archive are not recorded by the trail. A deleted or overwritten log file would not appear as an event. Log file integrity validation exposes tampering with delivered logs, versioning with noncurrent-version retention preserves earlier copies (0007), and preventing deletion is the job of a service control policy.
- Terraform is blocked from destroying the bucket (0007) and its name is permanent, but if it is ever replaced, the selector must be updated in the same change, or the feedback loop returns.
- Terraform state access in the shared security account is recorded as data events, which gives a record of every read and write of state.