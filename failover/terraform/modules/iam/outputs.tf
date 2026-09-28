output "instance_profile_name" {
  description = "Name of the created IAM instance profile"
  value       = aws_iam_instance_profile.this.name
}

output "role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}
