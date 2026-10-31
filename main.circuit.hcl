# Facts give each host's distribution, which picks the package names.
data "conn3x_host" "facts" {
  for_each = var.hosts

  ssh {
    host             = try(each.value.address, each.value)
    host_key         = try(each.value.host_key, null)
    user             = try(each.value.user, var.ssh_user)
    port             = try(each.value.port, var.ssh_port)
    private_key_file = try(each.value.private_key_file, var.ssh_private_key_file)
    jump_hosts       = try(each.value.jump_hosts, null)
    known_hosts_file = var.ssh_known_hosts_file
  }
}

locals {
  nasm_in_crb = { for name in keys(var.hosts) : name => contains(["rocky", "almalinux", "centos"], data.conn3x_host.facts[name].os_id) }
}

circuit "c_toolchain" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  step "package" {
    for_each = ["gcc", "make", "gdb"]
    package {
      name = item.value
    }
  }

  # Rocky Linux, AlmaLinux and CentOS Stream keep nasm in CRB, which is off by
  # default. These two steps take it from there for that one install, leaving
  # the repository off, and from the usual place everywhere else.
  step "nasm" {
    package {
      name = local.nasm_in_crb[each.key] ? "gcc" : "nasm"
    }
  }

  step "nasm_crb" {
    command {
      command = local.nasm_in_crb[each.key] ? "dnf -y --enablerepo=crb install nasm" : "true"
      unless  = local.nasm_in_crb[each.key] ? "rpm -q nasm" : "true"
    }
  }

  step "cxx" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "g++" : "gcc-c++"
    }
  }

  # gcc only recommends these on Debian and Ubuntu, and a recommendation might
  # not be installed.
  step "libc" {
    package {
      name = data.conn3x_host.facts[each.key].os_family == "debian" ? "libc6-dev" : "glibc-devel"
    }
  }
}
