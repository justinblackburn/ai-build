# Inventory examples

Two complete inventories, one per environment. Copy the one you need to `ansible/inventory`:

| Folder | Host | Use |
|---|---|---|
| `bare-metal/` | `metal` (local, GPU) | the GPU host itself |
| `vm/` | `default` (local, in the Vagrant VM) | the Vagrant VM, mounted at `/mnt/inventory` |

```bash
cp -R ansible/inventory.example/bare-metal ansible/inventory   # bare metal
cp -R ansible/inventory.example/vm ansible/inventory           # VM
```

Each folder holds everything the environment needs:

- `hosts.yml`: the host or hosts.
- `group_vars/all.yml`: settings shared by all hosts in the inventory.
- `host_vars/<host>.yml`: settings for one host (models, bind addresses, cache paths).

Keep the two inventories separate, so a VM run never targets the bare-metal host.

## Vault values

Passwords and keys are the only values that are not in these files as plain text. They are:

- `rhsm_org` and `rhsm_key` (Red Hat subscription)
- `llm_rag_pg_password` (RAG Postgres)

Each one is shown as `CHANGE_ME` in the example. Replace it with an encrypted value:

```bash
printf '%s' 'THE-VALUE' | ansible-vault encrypt_string \
  --vault-password-file ansible/.vault_pass.txt --stdin-name llm_rag_pg_password
```

Paste the output (the `llm_rag_pg_password: !vault |` block) in place of the `CHANGE_ME` line in `group_vars/all.yml`.
Use `--stdin-name rhsm_org` and `--stdin-name rhsm_key` for the subscription values.

Keep the vault password file out of git. Use a different vault password file for each environment if you want their secrets separate.

## Versions and paths

- The NVIDIA driver version is set in `roles/nvidia/defaults/main.yml`, not in the inventory.
- The Python version for the Whisper venv is set in `roles/whisper/defaults/main.yml`.
- The bare-metal cache is `~/github/.cache`. The VM's working cache is `/var/tmp/.cache`, which the Vagrantfile fills.
