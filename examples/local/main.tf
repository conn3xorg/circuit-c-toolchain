variable "port" {
  type    = number
  default = 2337
}

module "c_toolchain" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"
}

output "cc" {
  value = module.c_toolchain.cc
}
