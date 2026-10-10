output "ecr_repository_url" {
  description = "ECR URL"
  value       = aws_ecr_repository.app.repository_url
}

output "db_endpoint" {
  description = "RDS endpoint"
  value       = aws_db_instance.db.endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager ARN holding the RDS master credentials"
  value       = aws_db_instance.db.master_user_secret[0].secret_arn
}

output "alb_dns_name" {
  description = "ALB DNS"
  value       = aws_lb.alb.dns_name
}
