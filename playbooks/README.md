# ansible-collection-daos playbooks

List of playbooks in this collection

| Playbook                    | FQN                  | Description                                                   |
| ---------------------------- | -------------------- | ------------------------------------------------------------- |
| [daos_cluster.yml](playbooks/daos_cluster.yml) | `daos_stack.daos.daos_cluster` | Sets up a DAOS cluster consisting of DAOS servers, clients, and a single admin node |
| [i0500_install.yml](playbooks/io500_install.yml) | `daos_stack.daos.io500_install` | Installs [io500](https://github.com/IO500/io500). Currently WIP. Do not use! |

### Running the playbooks

To run a playbook from this collection:

```bash
ansible-playbook <FQN>
```

For example, to run the [daos_cluster.yml](playbooks/daos_cluster.yml) playbook:

```bash
ansible-playbook daos_stack.daos.daos_cluster
```
