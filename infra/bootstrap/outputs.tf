output "ecr_repository_name" {
  description = "Name of the ECR repository created for the application."
  value       = aws_ecr_repository.gamehub.name
}

output "ecr_repository_url" {
  description = "URL used to tag and push Game Hub container images."
  value       = aws_ecr_repository.gamehub.repository_url
}
