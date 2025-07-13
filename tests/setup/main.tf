terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}

resource "random_id" "suffix" {
  byte_length = 2
}

# Generate fake IDs to feed into module tests without touching AWS
locals {
  suffix = random_id.suffix.hex
}

output "vpc_id" {
  value = "vpc-${local.suffix}"
}

output "public_subnet_ids" {
  value = [
    "subnet-${local.suffix}a",
    "subnet-${local.suffix}b"
  ]
}

output "security_group_ids" {
  value = ["sg-${local.suffix}"]
}

output "suffix" {
  value = local.suffix
}
