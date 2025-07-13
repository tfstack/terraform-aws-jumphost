###############################################
# Provider stub – fast local-only execution
###############################################
provider "aws" {
  region                      = "ap-southeast-2"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

###############################################
# Phase 1 – Setup networking prerequisites
###############################################
run "setup_network" {
  module {
    source = "./tests/setup"
  }
}

###############################################
# Phase 2 – Plan jumphost creation
###############################################
run "plan_jumphost" {
  command = plan

  variables {
    # feed dummy IDs from setup
    subnet_id              = element(run.setup_network.public_subnet_ids, 0)
    vpc_security_group_ids = run.setup_network.security_group_ids
    vpc_id                 = run.setup_network.vpc_id

    name            = "test-jumphost-${run.setup_network.suffix}"
    ami_id_override = "ami-0123456789abcdef0"
    create          = true
    assign_eip      = false
  }

  ##########################################################
  # Assertions – verify resource count & key attributes
  ##########################################################
  assert {
    condition     = length(aws_instance.this) == 1
    error_message = "Expected one EC2 instance to be planned."
  }

  assert {
    condition     = aws_instance.this[0].instance_type == var.instance_type
    error_message = "Instance type mismatch in plan."
  }

  assert {
    condition     = aws_instance.this[0].ami == var.ami_id_override
    error_message = "AMI ID not honoured by module."
  }
}

###############################################
# Phase 3 – Validation failure scenario
###############################################
run "invalid_ami_type" {
  command = plan

  variables {
    subnet_id              = element(run.setup_network.public_subnet_ids, 0)
    vpc_security_group_ids = run.setup_network.security_group_ids
    ami_type               = "centos" # unsupported per validation
  }

  expect_failures = [
    var.ami_type
  ]
}
