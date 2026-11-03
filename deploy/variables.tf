variable "region" {
  description = "AWS region to deploy into. Any region works — the pod only needs outbound internet."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type. A small box is plenty for a single pod router."
  type        = string
  default     = "t3.small"
}

variable "arch" {
  description = "CPU architecture for the Ubuntu AMI lookup: amd64 (t3/t2/m) or arm64 (t4g/c7g)."
  type        = string
  default     = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "arch must be amd64 or arm64 (and must match instance_type's family)."
  }
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH in (set to YOUR_IP/32). Account-specific — keep it in a gitignored terraform.tfvars."
  type        = string
}

variable "name_prefix" {
  description = "Name/tag prefix for the created resources."
  type        = string
  default     = "velmara-pod-demo"
}
