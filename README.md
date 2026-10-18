# ai-build

Ansible for the base of an AI workstation on **RHEL 9**: the OS repositories and tools, the service accounts,
Podman, and the NVIDIA driver and container toolkit. It is the first step of a rebuild. The application stack
(Ollama, the RAG service, the CallGuard environment and the Whisper tool) is in ai-application-infra, which runs
after this one.

## What it installs

`ansible/playbooks/install.yml` runs these roles, in order:

| Role | What it does |
|---|---|
| `base` | Subscription registration and repos (EPEL, CodeReady Builder, RPM Fusion for ffmpeg, the NVIDIA repo for drivers). Development tools, `git`, `ansible-core`, and the `containers.podman` collection that the infra playbooks load. |
| `users` | The service accounts `ollama` (runs Ollama) and `callguard` (runs the CallGuard services and Whisper). Both are system accounts with no login shell and no sudo. Plus any users listed in the inventory. |
| `podman` | Podman, for the containers the infra playbooks run. |
| `nvidia` | The NVIDIA driver, pinned to **615.71.09** from NVIDIA's RHEL 9 repo (`nvidia-driver`, `nvidia-driver-cuda`, `nvidia-driver-cuda-libs`, and the DKMS kernel module `kmod-nvidia-open-dkms`), locked with versionlock. Also the NVIDIA container toolkit and the kernel arguments the driver needs. |

No models or application data are downloaded here. The models are in ai-application-infra.

Each role has its own README with its variables.

## Playbooks

| Playbook | Use |
|---|---|
| `install.yml` | The full base install: all four roles. |
| `base.yml`, `users.yml`, `podman.yml`, `nvidia.yml` | One role each, for iterating on that part. |

Run them from `ansible/` with a populated inventory:

```bash
cd ansible
ANSIBLE_ROLES_PATH=$PWD/playbooks/roles \
  ansible-playbook -i <inventory>/hosts.yml --vault-password-file <vault-pass-file> playbooks/install.yml
```

The inventory and the vault password are not in this repo. See the next section.

## Inventory and secrets

Two complete examples are in `ansible/inventory.example`:

- `bare-metal/`: the GPU host (`metal`, local).
- `vm/`: the Vagrant VM (`default`, local).

Copy the one you need to `ansible/inventory`. Each has `hosts.yml`, `group_vars/all.yml`, and `host_vars/`, and the
examples set every variable the roles read. Passwords and keys are `CHANGE_ME` placeholders. Replace them with vault
values as described in `ansible/inventory.example/README.md`.

Keep the vault password file out of git. The inventories are not in git either. Keep them in a private place and
copy them to a new machine yourself.

## Requirements

- RHEL 9 with a Red Hat subscription (org and activation key, in the vault).
- `sudo` access for the playbooks.
- Network access to Red Hat's CDN, NVIDIA's repo (`developer.download.nvidia.com`), EPEL, and RPM Fusion.

## Repository layout

```
ansible/
  ansible.conf.example       copy to ansible.cfg
  inventory.example/         bare-metal and VM inventories (see above)
  playbooks/
    install.yml              the full base install
    base.yml users.yml podman.yml nvidia.yml
    roles/                   base, users, podman, nvidia
.env.example                 copy to .env: paths for ansible
```

## Notes

- Stable Diffusion, the older RAG role, and the Whisper role were removed from this repo. Whisper and the RAG
  stack are installed by ai-application-infra.
- `ansible/.htpasswd` is no longer tracked. Keep any local credentials out of git.
