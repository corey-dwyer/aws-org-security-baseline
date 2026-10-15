locals {
  # Every protection plan the provider can manage, stated explicitly. Only S3 is on,
  # because it matches the S3 techniques in scope. The rest are written as DISABLED
  # and not omitted: deleting a feature resource does not turn the feature off, so
  # a declared DISABLED is what gives drift detection if someone enables a plan in
  # the console. DNS and flow log analysis are always on and cannot be managed.
  # EKS runtime monitoring is not listed: the provider allows only one of the two
  # runtime features, and RUNTIME_MONITORING already covers EKS.
  guardduty_features = {
    S3_DATA_EVENTS         = "ENABLED"
    EKS_AUDIT_LOGS         = "DISABLED"
    EBS_MALWARE_PROTECTION = "DISABLED"
    RDS_LOGIN_EVENTS       = "DISABLED"
    LAMBDA_NETWORK_LOGS    = "DISABLED"
    RUNTIME_MONITORING     = "DISABLED"
    AI_PROTECTION          = "DISABLED"
    AI_ANALYST             = "DISABLED"
  }

  # Sub-settings that AWS stores under two features. They must be declared, or the
  # provider plans to remove them and AWS returns them again on every read, so the
  # plan never settles. All are DISABLED, matching their parent features. Revisit
  # them when a parent feature is ever enabled.
  guardduty_additional_configurations = {
    RDS_LOGIN_EVENTS   = ["RDS_DATA_RISK"]
    RUNTIME_MONITORING = ["EKS_ADDON_MANAGEMENT", "ECS_FARGATE_AGENT_MANAGEMENT", "EC2_AGENT_MANAGEMENT"]
  }

  # AI_ANALYST is not offered in every Region: as of the last check, these ten accept
  # it and the other seven reject the feature name. It is managed only where it exists.
  # A Region missing from this list is simply not managed for this feature, which is
  # the safe direction. If AWS withdraws it from a listed Region, the apply fails and
  # the list is corrected.
  ai_analyst_regions = toset([
    "ap-northeast-1",
    "ca-central-1",
    "eu-central-1",
    "eu-north-1",
    "eu-west-1",
    "eu-west-2",
    "eu-west-3",
    "us-east-1",
    "us-east-2",
    "us-west-2",
  ])

  # One entry for every Region and feature pair, keyed "region/feature".
  guardduty_region_features = {
    for pair in setproduct(var.guardduty_regions, keys(local.guardduty_features)) :
    "${pair[0]}/${pair[1]}" => { region = pair[0], name = pair[1] }
    if pair[1] != "AI_ANALYST" || contains(local.ai_analyst_regions, pair[0])
  }
}

resource "aws_guardduty_detector" "this" {
  for_each = var.guardduty_regions

  region                       = each.key
  enable                       = true
  finding_publishing_frequency = "FIFTEEN_MINUTES"

  # Destroying a detector disables GuardDuty in that Region and deletes its findings.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_guardduty_detector_feature" "this" {
  for_each = local.guardduty_region_features

  region      = each.value.region
  detector_id = aws_guardduty_detector.this[each.value.region].id
  name        = each.value.name
  status      = local.guardduty_features[each.value.name]

  dynamic "additional_configuration" {
    for_each = lookup(local.guardduty_additional_configurations, each.value.name, [])

    content {
      name   = additional_configuration.value
      status = "DISABLED"
    }
  }
}