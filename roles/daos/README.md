# Role: daos

This Ansible role will install and configure DAOS on a host.

> A host can be a bare metal machine, VM, or container. The term *host* will be used in the documentation below to refer to any target where the `daos_stack.daos.daos` *Ansible role* will run.

In this README.md file the term "role" is overloaded.

- Used to refer to the `daos_stack.daos.daos` *Ansible role*
- The role that a host is assigned within a [DAOS system](https://docs.daos.io/latest/overview/architecture/#daos-system). A host may take on the role of a DAOS server, a DAOS client, a DAOS admin or any combination of the three.

In a [DAOS system](https://docs.daos.io/latest/overview/architecture/#daos-system) hosts can be assigned one or more of the following roles:

- **DAOS Server**
  Runs the DAOS Server multi-tenant daemon. Its Engine sub-processes export the locally-attached SCM and NVM storage through the network.
- **DAOS Client**
  Runs the DAOS agent daemon that interacts with the DAOS library to authenticate application processes. The agent daemon can support different authentication frameworks, and uses a Unix Domain Socket to communicate with the DAOS library.
- **DAOS Admin**
  Has the DAOS admin utilities installed. Typically used by administrators to manage the DAOS system.

When using the `daos_stack.daos.daos` Ansible role to install a DAOS on a target host, you must determine the DAOS system *role* that host will be assigned within the DAOS system. For more information see the documentation for the `daos_role` variable below.

## Requirements

Any pre-requisites that may not be covered by Ansible itself or the role should be mentioned here. For instance, if the role uses the EC2 module, it may be a good idea to mention in this section that the boto package is required.

## Role Variables

A description of the settable variables for this role should go here, including any variables that are in defaults/main.yml, vars/main.yml, and any variables that can/should be set via parameters to the role. Any variables that are read from other roles and/or the global scope (ie. hostvars, group vars, etc.) should be mentioned here as well.

## Dependencies

A list of other roles hosted on Galaxy should go here, plus any details in regards to parameters that may need to be set for other roles, or variables that are used from other roles.

## Example Playbook

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

```yaml
- hosts: daos_servers
  roles:
    - { role: daos_stack.daos.daos.daos, daos_roles: [server] }
```
Or

```yaml
- hosts: daos_servers
  roles:
    - role: daos_servers
      vars:
        daos_roles: [server]
```

## Installation Scenarios

Need to test and document the following scenarios.

### Local Connections

1. Packer provisioner to install DAOS for image builds
2. Configure systems using ansible pull from cloud-init user_data
3. Configure a single server
   - Run in local mode and install DAOS server, client and admin on a single host
4. Configure a developer workstation
   - Set up a workstation for DAOS development
5. Install DAOS from source


### Remote Connections

1. Configure a single remote host as a standalone DAOS cluster
2. Install a full cluster on a set of remote hosts from an Ansible controller
3. Perform configuration only on remote hosts
4. Perform storage administration only on remote hosts
