# ai-build

---

## Overview

**Goal:** Build a fully reproducible pipeline that transcribes lectures, indexes material for retrieval, and generates study guides and quizzes automatically using LLMs — all running locally on **RHEL 9**.  

In practice, that means:  
- Containerized **Whisper**  
- A **Retrieval-Augmented Generation (RAG)** workflow
- Optional **Stable Diffusion** integration for visual summaries  
- Infrastructure managed by **Ansible** and **Podman**

---

## Architecture

**Base OS:** RHEL 9  
**Hardware:** Ryzen 9 5800X | RTX 4080 | 64 GB DDR5  

**Core Tools:**  
- `Ansible` – reproducible provisioning and configuration  
- `Podman` – container management without Docker overhead  
- `Whisper` – transcription model for lecture audio  
- `LLM` (local or remote) – quiz and study-guide generation  
- `Stable Diffusion` – optional visualization layer  

Each component is deployed via modular Ansible roles for easy teardown and rebuild.  

---

## Repository Layout

```
ai-build/
├── ansible/
│   ├── roles/
│   │   ├── base/
│   │   ├── users/
│   │   ├── podman/
│   │   ├── whisper/
│   │   ├── rag/
│   │   └── llm/
│   └── playbooks/
│       ├── build.yml
│       └── teardown.yml
├── vagrant/
│   └── rhel9/
└── README.md
```

---

## Getting Started

1. **Clone the repo**  
   ```bash
   git clone https://github.com/justinblackburn/ai-build.git
   cd ai-build/ansible
   ```

2. **Register your RHEL 9 host** with Red Hat Subscription Manager  

3. **Install Ansible and dependencies**  
   ```bash
   sudo dnf install -y ansible git
   ```

4. **Run the base playbook**  
   ```bash
   ansible-playbook playbooks/build.yml
   ```

5. **Check the `roles/` directory** for service-specific setups (Whisper, RAG, LLM, etc.)

---

## Status

- RHEL 9 + Podman base roles complete  
- Whisper transcription containerized  
- RAG integration in progress  
- LLM and quiz generation testing  
- Kickstart automation and teardown scripts  

---

# ai-build Inventory Reference

This file documents the inventory structure and variable files used in the **ai-build** Ansible automation project.

---

## Directory Layout

```
ansible/
├── inventory/
│   ├── hosts.yml
│   └── group_vars/
│       └── all.yml
└── vars/
    └── secrets.yml
```

---

## hosts.yml

```yaml
---
all:
  vars:
    ansible_python_interpreter: /usr/bin/python3
    base_dir: /opt/ai-build
    data_dir: /home/sd/data
    log_dir: /var/log/ai-build
    gpu_enabled: true
    podman_network: ai-net
    podman_storage_driver: overlay
    enable_rag: true
    enable_stable_diffusion: true

  children:
    local:
      hosts:
        localhost:
          ansible_connection: local
          ansible_become: true

    lab:
      hosts:
        rhel9-lab:
          ansible_host: 192.168.122.100
          ansible_user: justin
          ansible_become: true
```

---

## group_vars/all.yml

```yaml
---
# Global Variables for ai-build

# --- Subscription Management ---
enable_subscription: true
is_vagrant: false

rhsm_org: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          # (encrypted Red Hat org ID goes here)

rhsm_key: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          # (encrypted Red Hat activation key goes here)

# --- NVIDIA Driver Settings ---
nvidia_driver_url: "https://us.download.nvidia.com/XFree86/Linux-x86_64/550.78/NVIDIA-Linux-x86_64-550.78.run"
nvidia_driver_file: "{{ nvidia_driver_url | basename }}"

# --- User Definitions ---
users:
  - name: blah
    password: !vault |
              $ANSIBLE_VAULT;1.1;AES256
              # (encrypted password hash)
    shell: /bin/zsh
    groups: [wheel]
    system: false
    enable_podman: true
    directories: []

  - name: sd-data
    shell: /sbin/nologin
    system: true
    enable_podman: true
    directories:
      - /home/sd-data
      - /home/sd-data/data
```

---

## vars/secrets.yml

```yaml
---
# Encrypted secrets for ai-build
# Encrypt this file using ansible-vault before committing.

openai_api_key: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          # (OpenAI or LLM API key)
hf_token: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          # (Hugging Face API token)
wandb_api_key: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          # (Weights & Biases API key)
```

## Local Testing with Vagrant

Vagrant is used to spin up disposable RHEL-based VMs for testing your Ansible roles and automation workflows.  
This allows you to validate builds without affecting your primary RHEL system.

### Requirements
- Vagrant (2.3+ recommended)  
- VirtualBox or libvirt provider  
- RHEL 9 or CentOS Stream 9 Vagrant box  

### Setup

```bash
cd vagrant/rhel9
vagrant up
```

This boots a minimal RHEL environment and provisions it automatically using the Ansible playbooks from the repo.

### Usage

Once the VM is up, connect to it and test your playbooks directly:

```bash
vagrant ssh
cd /vagrant/ansible
ansible-playbook playbooks/build.yml
```

### Rebuilding

If you want to reset the environment completely:

```bash
vagrant destroy -f && vagrant up
```
