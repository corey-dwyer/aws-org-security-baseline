resource "aws_sns_topic" "log_archive_objects" {
  name = "log-archive-object-created"
}

resource "aws_sns_topic_policy" "log_archive_objects" {
  arn = aws_sns_topic.log_archive_objects.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowS3PublishFromLogArchiveBucket"
        Effect    = "Allow"
        Principal = { Service = "s3.amazonaws.com" }
        Action    = "SNS:Publish"
        Resource  = aws_sns_topic.log_archive_objects.arn
        Condition = {
          ArnEquals    = { "aws:SourceArn" = aws_s3_bucket.log_archive.arn }
          StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
        }
      },
    ]
  })
}

resource "aws_s3_bucket_notification" "log_archive" {
  bucket = aws_s3_bucket.log_archive.id

  topic {
    topic_arn = aws_sns_topic.log_archive_objects.arn
    events    = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_sns_topic_policy.log_archive_objects]
}