output "public_ip" {
  description = "Public IP of the pod host."
  value       = aws_instance.pod.public_ip
}

output "instance_id" {
  description = "EC2 instance id."
  value       = aws_instance.pod.id
}

output "ssh_command" {
  description = "Ready-to-use SSH command (private key was written locally, gitignored)."
  value       = "ssh -i ${local_sensitive_file.ssh_key.filename} ubuntu@${aws_instance.pod.public_ip}"
}
