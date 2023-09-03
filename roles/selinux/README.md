selinux
=========

Role that that sets the SELINUX value in the /etc/selinx/config file.

## Requirements

None

## Role Variables

```yaml
# selinux_state: <enforcing|permissive|disabled>
selinux_state: disabled
```

## Dependencies

None

## Example Playbook

```yaml
---
- name: Disable selinux
  hosts: all

  roles:
    - role: daos_stack.daos.selinux
```
