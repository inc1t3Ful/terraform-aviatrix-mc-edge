terraform {
  experiments = [module_variable_optional_attrs]

  required_providers {
    aviatrix = {
      source  = "aviatrixsystems/aviatrix"
      version = "~> 2.23.0"
    }
  }
  required_version = ">= 1.2.0"
}
