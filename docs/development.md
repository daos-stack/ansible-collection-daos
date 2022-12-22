# Development

Instructions for setting up your system to develop and test the content in the
`ansible-collection-daos` collection.

---

> **TODO:** Create this documentation



## Patch podman.py

Roles in this ansible collection are tested with podman.

Unfortunately, there is a bug which needs a patch.

To apply the patch, run:

```bash
podman_path=$(find $VIRTUAL_ENV -type f -name podman.py)
patch $podman_path podman.py.patch
```

## Testing roles with molecule

**WARNING:**

As of November 2022 molecule tests were broken and therefore have not been used. We need to go back through all roles and fix the molecule tests.

```bash
cd roles/<role_name>
molecule test
```
