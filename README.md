# Ansible Collection for DAOS

Ansible Collection for DAOS

**Not recommended for production!**

This collection is still in the **very** early stages of development and still has a long way to go. Documentation is sparse. The code and the `defaults/main.yml` files are the documentation for the roles in the collection.

**Table of Contents**

- [Features](#features)
    - [Inventory](#inventory)
    - [Install DAOS Version](#install-daos-version)
    - [OS support](#os-support)
    - [Run as](#run-as)
    - [Prerequisites](#prerequisites)
- [Installation Instructions](#installation-instructions)
  - [Install on a DAOS admin node](#install-on-a-daos-admin-node)
  - [Install on a node where Ansible is already installed](#install-on-a-node-where-ansible-is-already-installed)
- [Inventory](#inventory-1)
  - [Inventory group\_vars configuration](#inventory-group_vars-configuration)
    - [Configuration for the daos role](#configuration-for-the-daos-role)
      - [Example configuration in a `~/ansible-daos/group_vars/daos_servers/daos` file](#example-configuration-in-a-ansible-daosgroup_varsdaos_serversdaos-file)
- [Roles](#roles)
- [Playbooks](#playbooks)
  - [Running the playbooks](#running-the-playbooks)
- [Disclaimer](#disclaimer)
- [License](#license)

## Features

#### Inventory

- [x] Pre-built infrastructure (use static inventory file and group_vars directory)
- [ ] Dynamic inventory

#### Install DAOS Version

- [ ] DAOS v1.2
- [ ] DAOS v2.0
- [x] DAOS v2.2

#### OS support

- [x] EL8 (Rocky Linux, AlmaLinux, RHEL 8) on x86_64
- [ ] EL9 (Rocky Linux, AlmaLinux, RHEL 9) on x86_64
- [ ] openSUSE Leap 15.3 on x86_64
- [ ] openSUSE Leap 15.4 on x86_64
- [ ] Debian
- [ ] Ubuntu

#### Run as

- [ ] Root
- [x] User named `ansible`.

  All target hosts must have an `ansible` user that has passwordless sudo permissions.

  The `/home/ansible/.ssh/authorized_keys` file on all target hosts must contain the public key of the the user who is running ansible commands on the control host.

#### Prerequisites

In order to use this Ansible collection

- [x] A current version of Python3 must be installed on all hosts.
      Python 3.9 or higher is preferred. At this time many distros
      default to Python 3.6 which will not be supported in future
      versions of Ansible.
- [x] Passwordless SSH as `ansible` user from Ansible control host must be configured on all hosts. The username can be changed in the `ansible.cfg` file.
- [x] `ansible` user must have passwordless sudo permission on all target hosts
- [x] Port 22 must be open between the Ansible controller and all target hosts
- [x] All target hosts must have port 443 open to https://github.com and https://packages.daos.io
- [x] Port 10001 must be open between all hosts with any DAOS packages installed.
- [x] Time must be in sync on all target hosts. Use NTP or Chrony.
- [x] If DNS is not available, the `/etc/hosts` file on the Ansible controller must contain IPs and hostnames for all target hosts and the Ansible inventory `hosts` file must have the `ansible_host=<ip>` attribute set for each host.
- [x] You must have an SSH key pair to connect to the DAOS admin host (bastion).

## Installation Instructions

### Install on a DAOS admin node

If you plan to use this collection on a DAOS admin node (bastion) the [install_ansible.sh](install_ansible.sh) script in this repository can be used to install Ansible, install this collection, and set up a project directory with a skelaton inventory.

The [install_ansible.sh](install_ansible.sh) script does the following:

- Install a current version of Python3
- Create a `~/ansible-daos` Ansible project directory
- Set up a Python3 virtual environment in `~/ansible-daos/.venv`
- Create `~/ansible-daos/group_vars` for inventory vars
- Create `~/ansible-daos/ansible.cfg`
- Install the daos-stack/daos collection

To install Ansible and this collection on a DAOS Admin node, log on as the user who
will be running ansible commands and then run:

```bash
curl -s https://raw.githubusercontent.com/daos-stack/ansible-collection-daos/main/install_ansible.sh | bash -s
```

To run ansible commands:

1. Change your working directory to `~/ansible-daos`
2. Activate the virtual environment

```bash
cd ~/ansible-daos
source .venv/bin/activate
```

After activating the virtual env Ansible commands can be run from within the `~/ansible-daos` directory.

It's necessary to run Ansible commands within `~/ansible-daos` because the `ansible.cfg` file in that directory is configured to run ansible as the `ansible` user with sudo when running tasks on remote hosts.

### Install on a node where Ansible is already installed

To install the collection on a node where Ansible is already installed run:

```bash
ansible-galaxy collection install "git+https://github.com/daos-stack/ansible-collection-daos.git"
```

To install the version in the develop branch run:

```bash
ansible-galaxy collection install "git+https://github.com/daos-stack/ansible-collection-daos.git,develop"
```

## Inventory

This collection requires that the following host groups are present in the inventory:

- daos_servers
- daos_clients
- daos_admins

If you installed Ansible using the [install_ansible.sh](install_ansible.sh) script as described above, a `~/ansible-daos/hosts` file will be created.

The `~/ansible-daos/hosts` file will only contain one host entry.

```
[daos_admins]
localhost ansible_connection=local

[daos_clients]

[daos_servers]

[daos_cluster:children]
daos_admins
daos_clients
daos_servers
```

The `~/ansible-daos/hosts` file will need to be updated to contain the names of all DAOS hosts. Any DAOS servers which serve as [access_points](https://docs.daos.io/v2.2/QSG/setup_rhel/?h=access_points#create-configuration-files) must have the `is_access_point=true` attribute added to the entry in the `hosts` file.

```
# file: ~/ansible-daos/hosts

[daos_admins]
daos-admin-001 ansible_connection=local

[daos_clients]
daos-client-[001:016]

[daos_servers]
daos-server-001 is_access_point=true
daos-server-002 is_access_point=true
daos-server-003 is_access_point=true
daos-server-004
daos-server-005

[daos_cluster:children]
daos_admins
daos_clients
daos_servers
```

### Inventory group_vars configuration

If the [install_ansible.sh](install_ansible.sh) script was used to install Ansible and this collection, then the `~/ansible-daos/group_vars` directory will contain a basic configuration with variables set for the `daos_stack.daos.daos` role.

```
~/ansible-daos/
├── ansible.cfg
├── group_vars
│   ├── all
│   ├── daos_admins
│   │   └── daos
│   ├── daos_clients
│   │   └── daos
│   └── daos_servers
│       ├── daos
│       └── tuned
└── hosts
```

#### Configuration for the daos role

The `daos_stack.daos.daos` Ansible role will generate the [`/etc/daos/daos_server.yml`](https://docs.daos.io/v2.2/QSG/setup_rhel/?h=access_points#create-configuration-files) file on the DAOS servers.

You will need to set variables in `~/ansible-daos/group_vars/daos_servers/daos` file in order to generate the proper `/etc/daos/daos_server.yml` for the hardware that will be used for DAOS servers.

DAOS server configuration is beyond the scope of this documentation. For details see the [Create Configuration Files in Installation and Setup section of the DAOS documentation](https://docs.daos.io/v2.2/QSG/setup_rhel/#create-configuration-files).

##### Example configuration in a `~/ansible-daos/group_vars/daos_servers/daos` file

```yaml
---
daos_roles:
  - admin
  - server

daos_server_provider: "ofi+tcp;ofi_rxm"
daos_server_disable_vfio: "false"
daos_server_disable_vmd: "false"
daos_server_enable_hotplug: "false"
daos_server_crt_timeout: 60
daos_server_disable_hugepages: "false"
daos_server_control_log_mask: "INFO"
daos_server_log_dir: /var/daos
daos_server_control_log_file: "/var/daos/daos_server.log"
daos_server_helper_log_file: "/var/daos/daos_admin.log"
daos_server_firmware_helper_log_file: "/var/daos/daos_firmware.log"
daos_server_telemetry_port: 9191

daos_server_engines:
  - targets: 16
    nr_xs_helpers: 0
    bypass_health_chk: true
    fabric_iface: ens1
    fabric_iface_port: 31316
    log_mask: DEBUG
    log_file: /var/daos/daos_engine_0.log
    env_vars:
      - "FI_OFI_RXM_DEF_TCP_WAIT_OBJ=pollfd"
      - "DTX_AGG_THD_CNT=16777216"
      - "DTX_AGG_THD_AGE=700"
    storage:
      - scm_mount: /var/daos/ram0
        class: ram
        scm_size: 300
      - class: nvme
        bdev_list: ["0000:5d:05.5", "0000:3a:05.5", "0000:85:05.5"]

daos_pools:
  - name: pool1
    size: "2TB"
    tier_ratio: 3
    user: root
    group: root
    acls:
      - "A::EVERYONE@:rcta"
    properties: []
```

## Roles

More work needs to be done to document the roles within this collection.

**List of roles**

| Role Name                    | FQN                  | Description                                                   |
| ---------------------------- | -------------------- | ------------------------------------------------------------- |
| [daos](roles/daos/README.md) | `daos_stack.daos.daos` | Installs and configures DAOS Servers, Clients and Admin nodes |
| [epel](roles/epel/README.md) | `daos_stack.daos.epel` | Installs [epel](https://docs.fedoraproject.org/en-US/epel/) |
| [i0500](roles/io500/README.md) | `daos_stack.daos.io500` | Installs [io500](https://github.com/IO500/io500). Currently WIP. Do not use! |
| [packages](roles/packages/README.md) | `daos_stack.daos.packages` | Installs additional packages that are useful on DAOS nodes. See the `_packages_common` variable in [roles/packages/vars/main.yml](roles/packages/vars/main.yml) for list of packages that this role installs.|
| [reboot](roles/reboot/README.md) | `daos_stack.daos.reboot` | Reboots a host |
| [tune](roles/tune/README.md) | `daos_stack.daos.tune` | Installs a custom [tuned](https://tuned-project.org/) profile |

## Playbooks

This collection contains playbooks that can be used for common use cases such as setting up a DAOS cluster or installing and running the IO500 Benchmark.

If these playbooks do not meet your needs, you can always create your own playbooks that use the roles in this collection.

| Playbook                    | FQN                  | Description                                                   |
| ---------------------------- | -------------------- | ------------------------------------------------------------- |
| [daos_cluster.yml](playbooks/daos_cluster.yml) | `daos_stack.daos.daos_cluster` | Sets up a DAOS cluster consisting of DAOS servers, clients, and a single admin node |
| [i0500_install.yml](playbooks/io500_install.yml) | `daos_stack.daos.io500_install` | Installs [io500](https://github.com/IO500/io500). Currently WIP. Do not use! |

### Running the playbooks

To run a playbook from this collection:

```bash
ansible-playbook <FQN>
```

To run the [daos_cluster.yml](playbooks/daos_cluster.yml) playbook:

```bash
ansible-playbook daos_stack.daos.daos_cluster
```

## Disclaimer

All roles, playbooks, and other content in this repo are available for use "AS IS" without any warranties of any kind, including, but not limited to their installation, use, or performance. Intel Corporation is not responsible for any damage or charges or data loss incurred with their use. You are responsible for reviewing and testing any scripts you run thoroughly before use in any production environment. This content is subject to change without notice.


## License

[Apache License 2.0](LICENSE)
