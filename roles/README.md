# Roles

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
