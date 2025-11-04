# `users` Role

Provisions user accounts, service accounts, home directories, sudo policies, and systemd lingering for rootless container support. This foundational role must run before roles that depend on specific users.

---

## Purpose

The `users` role manages system identities and permissions:

| Component | Description |
|-----------|-------------|
| **User Creation** | Interactive users and service accounts with customizable shells and groups |
| **Group Management** | Primary and supplementary group assignment |
| **Directory Provisioning** | Automated creation of user-owned directories |
| **Sudo Policy** | Configures wheel group for privileged access |
| **Systemd Lingering** | Enables persistent user services (required for rootless containers) |
| **Podman Integration** | Flags users for Podman configuration by downstream roles |

---

## Variables

The role consumes the global `users` list from inventory. No role-specific defaults file.

**User Schema** (in `inventory/group_vars/all.yml`):

```yaml
users:
  - name: sd-data                          # Username (required)
    password: "{{ 'plaintext' | password_hash('sha512') }}"  # Hashed password (optional)
    shell: /bin/bash                       # Login shell (default: /bin/bash)
    groups:                                # Supplementary groups (optional)
      - wheel
    service_group: sd-data                 # Primary group (default: same as name)
    home: /home/sd-data                    # Home directory (default: /home/NAME)
    system: true                           # System account flag (default: false)
    enable_podman: true                    # Enable Podman config (default: false)
    directories:                           # Directories to create (optional)
      - /home/sd-data/data
      - /opt/stable-diffusion-webui

  - name: jdoe                             # Interactive user example
    password: "{{ vault_jdoe_password }}"
    groups:
      - wheel
    enable_podman: false
    directories: []
```

**Field Reference**:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | **required** | Username for the account |
| `password` | string | omit | Hashed password (use `password_hash('sha512')` filter) |
| `shell` | string | `/bin/bash` | Login shell path |
| `groups` | list | `[]` | Supplementary groups (e.g., `wheel` for sudo) |
| `service_group` | string | `{{ name }}` | Primary group name |
| `home` | string | `/home/{{ name }}` | Home directory path |
| `system` | boolean | `false` | Create as system account (UID < 1000) |
| `enable_podman` | boolean | `false` | Enable Podman configuration (used by `podman` role) |
| `directories` | list | `[]` | Directories to create with user ownership |

---

## Role Workflow

### 1. Group Creation
For each user entry:
- Creates the primary group specified in `service_group`
- Uses `system: true` if user is a system account
- Skips if group already exists (idempotent)

### 2. User Account Creation
Creates user accounts with:
- Username from `name`
- Hashed password from `password` (if provided)
- Shell from `shell` (default: `/bin/bash`)
- Primary group from `service_group`
- Supplementary groups from `groups` list (appends, doesn't replace)
- Home directory at `home` path (auto-created)
- System account flag from `system`

**Example**: Service account creation:
```yaml
- name: sd-data
  service_group: sd-data
  system: true
```
Results in:
- User: `sd-data` (UID in system range, typically 900-999)
- Group: `sd-data` (GID matches UID)
- Home: `/home/sd-data`
- Shell: `/bin/bash`

### 3. Directory Provisioning
For each directory in `directories` list:
- Creates directory with mode `0755`
- Sets ownership to `name:service_group`
- Parent directories created automatically (equivalent to `mkdir -p`)

**Example**:
```yaml
directories:
  - /home/sd-data/data
  - /opt/stable-diffusion-webui
```
Both directories become owned by `sd-data:sd-data`.

### 4. Sudo Configuration
Writes `/etc/sudoers.d/wheel_nopasswd`:
```
%wheel ALL=(ALL) ALL
```
- Grants `wheel` group members full sudo access
- **Requires password** (no `NOPASSWD` directive)
- Mode `0440` (read-only by owner and group)

**Usage**: Add users to wheel group for sudo:
```yaml
groups:
  - wheel
```

### 5. Systemd Lingering
For users with `enable_podman: true` and `system: false`:
- Runs `loginctl enable-linger USERNAME`
- Allows user services to run without active login session
- Required for rootless container auto-start

**Effect**: User's systemd instance starts at boot and persists after logout.

---

## Prerequisites

- **Root Access**: Role requires privilege escalation for user/group creation
- **systemd**: Lingering requires systemd init system (standard on RHEL 9)
- **loginctl**: Part of systemd package (installed by default)

---

## Usage

### Standalone Execution

```bash
ansible-playbook playbooks/users.yml --ask-become-pass
```

### Add New User to Inventory

Edit `inventory/group_vars/all.yml`:

```yaml
users:
  # Existing users...

  # Add new developer account
  - name: alice
    password: "{{ 'changeme' | password_hash('sha512') }}"
    groups:
      - wheel
    directories:
      - /home/alice/projects
    enable_podman: true
```

Rerun the playbook to create the account.

---

## Post-Installation Verification

### Check User Created

```bash
# Verify user exists
id sd-data

# Expected output:
# uid=995(sd-data) gid=995(sd-data) groups=995(sd-data)

# Check home directory
ls -la /home/sd-data/

# Verify shell
grep sd-data /etc/passwd
```

### Test Sudo Access

```bash
# Switch to user with wheel membership
sudo -i -u jdoe

# Test sudo (will prompt for jdoe's password)
sudo whoami
# Expected: root
```

### Verify Lingering

```bash
# Check linger status
loginctl show-user sd-data | grep Linger

# Expected: Linger=yes

# List enabled linger users
ls /var/lib/systemd/linger/
```

### Check Directory Ownership

```bash
ls -la /home/sd-data/data/
ls -la /opt/stable-diffusion-webui/

# Both should show: drwxr-xr-x. sd-data sd-data
```

---

## Troubleshooting

### User Creation Fails - UID Conflict

**Symptom**: "UID already exists" error during user creation.

**Debug**:
```bash
# Check if UID is taken
getent passwd | grep 995

# Find next available system UID
sudo useradd --system --dry-run test-user
```

**Solution**: Let the system assign UID automatically (role default behavior). If you need specific UID:
```yaml
- name: sd-data
  uid: 1500  # Explicit UID (add this field to user dict)
```

### Password Not Working

**Symptom**: User can't log in with password.

**Debug**:
```bash
# Check if password hash is set
sudo getent shadow sd-data | cut -d: -f2

# Expected: $6$... (SHA-512 hash)
```

**Solution**: Ensure password is hashed in inventory:
```yaml
# Wrong - plaintext password
password: "mypassword"

# Correct - hashed password
password: "{{ 'mypassword' | password_hash('sha512') }}"

# Best - vaulted hash
password: "{{ vault_sd_data_password }}"
```

Generate hash manually:
```bash
python3 -c "from passlib.hash import sha512_crypt; print(sha512_crypt.hash('mypassword'))"
```

### Sudo Fails - Not in Wheel Group

**Symptom**: `user is not in the sudoers file` when running sudo.

**Debug**:
```bash
# Check group membership
id username | grep wheel

# Check sudoers file
sudo cat /etc/sudoers.d/wheel_nopasswd
```

**Solution**: Add user to wheel group in inventory:
```yaml
- name: username
  groups:
    - wheel
```

Rerun playbook, then verify:
```bash
groups username
```

### Lingering Not Enabled

**Symptom**: User services stop when logging out.

**Debug**:
```bash
loginctl show-user sd-data | grep Linger
# If shows: Linger=no

# Check if loginctl exists
which loginctl
```

**Solution**: Manually enable lingering:
```bash
sudo loginctl enable-linger sd-data
```

Or set `enable_podman: true` in inventory and rerun playbook.

### Directory Permission Denied

**Symptom**: User can't write to provisioned directory.

**Debug**:
```bash
ls -ld /home/sd-data/data/
# Check owner and mode
```

**Solution**: Fix ownership manually:
```bash
sudo chown -R sd-data:sd-data /home/sd-data/data/
sudo chmod 755 /home/sd-data/data/
```

Or add directory to `directories` list and rerun playbook.

---

## Security Considerations

### Password Hashing

**Never store plaintext passwords in inventory.**

**Best Practice**:
1. Generate hash:
   ```bash
   python3 -c "from passlib.hash import sha512_crypt; print(sha512_crypt.hash('YOUR_PASSWORD'))"
   ```

2. Encrypt hash with Ansible Vault:
   ```bash
   ansible-vault encrypt_string '$6$rounds=656000$...' --name 'vault_sd_data_password'
   ```

3. Use vaulted variable in inventory:
   ```yaml
   password: "{{ vault_sd_data_password }}"
   ```

### Sudo Password Requirement

The role configures wheel group with password requirement:
```
%wheel ALL=(ALL) ALL
```

**To enable NOPASSWD** (less secure, not recommended for production):

Edit `/etc/sudoers.d/wheel_nopasswd` after running role:
```
%wheel ALL=(ALL) NOPASSWD: ALL
```

Or modify the role task in [tasks/main.yml](tasks/main.yml):
```yaml
- name: Ensure wheel group has sudo (but with password)
  copy:
    content: '%wheel ALL=(ALL) NOPASSWD: ALL'
    # ...
```

### System Account UID Range

System accounts (`system: true`) get UIDs in the system range (typically < 1000):
- RHEL 9 default: 900-999
- Ensures separation from regular user accounts
- Used for service accounts like `sd-data`

### Home Directory Permissions

Created home directories have default permissions:
- Mode: `0755` (user can write, others can read/execute)
- Owner: User
- Group: Primary group

To restrict access:
```bash
chmod 700 /home/sd-data  # Only user can access
```

---

## Integration with Other Roles

### podman Role
Requires `users` role to run first:
- Iterates over users with `enable_podman: true`
- Creates `~/.config/containers/` directories
- Writes per-user `containers.conf`

**Dependency**:
```yaml
- name: sd-data
  enable_podman: true  # Signals podman role to configure this user
```

### stable_diffusion Role
Depends on `sd-data` user:
- Clones repositories as `sd-data`
- Creates venv owned by `sd-data`
- Runs services as `sd-data`

**Required**:
```yaml
- name: sd-data
  system: true
  directories:
    - /home/sd-data/data
    - /opt/stable-diffusion-webui
```

### whisper Role
Reuses `sd-data` user and directories:
- Shares venv with stable_diffusion
- Installs helper scripts in user's data directory

### llm_rag Role
Runs Podman containers as root (not user-specific), but benefits from:
- System directories created in `users` directories list
- Potential future migration to rootless Podman under service account

---

## Example User Configurations

### Service Account (AI Workloads)

```yaml
- name: sd-data
  service_group: sd-data
  system: true
  shell: /bin/bash
  enable_podman: true
  directories:
    - /home/sd-data/data
    - /opt/stable-diffusion-webui
```

**Use Case**: Runs Stable Diffusion, Whisper, isolated from human users.

### Developer Account (Sudo + Podman)

```yaml
- name: jdoe
  password: "{{ vault_jdoe_password }}"
  groups:
    - wheel
  shell: /bin/zsh
  enable_podman: true
  directories:
    - /home/jdoe/projects
    - /home/jdoe/workspace
```

**Use Case**: Human user with sudo access and container capabilities.

### Minimal Service Account (No Podman)

```yaml
- name: webapp
  system: true
  shell: /usr/sbin/nologin
  enable_podman: false
  directories:
    - /var/www/html
```

**Use Case**: Runs a web application, no interactive login or containers.

### Administrator Account (Sudo Only)

```yaml
- name: admin
  password: "{{ vault_admin_password }}"
  groups:
    - wheel
  shell: /bin/bash
  enable_podman: false
  directories: []
```

**Use Case**: Human administrator, no special directories or containers.

---

## Advanced Usage

### Multiple Supplementary Groups

```yaml
- name: devops
  groups:
    - wheel       # Sudo access
    - docker      # Docker socket access (if using Docker instead of Podman)
    - libvirt     # VM management
```

### Custom UID/GID

```yaml
- name: legacy-app
  uid: 5000
  service_group: legacy-app
  gid: 5000
  system: false
```

**Note**: Requires adding `uid` and `gid` parameters to role tasks (not in default role).

### Shared Group for Multiple Users

```yaml
# Create shared group first
- name: ai-team
  # User entry with no home (just creates group)
  service_group: ai-team
  home: /nonexistent
  shell: /usr/sbin/nologin

# Add users to shared group
- name: alice
  groups:
    - ai-team

- name: bob
  groups:
    - ai-team
```

Both users can access files owned by `ai-team` group.

---

## Related Roles

- **base**: No dependency (users can be created independently)
- **podman**: Requires users role to create accounts first
- **stable_diffusion**: Requires `sd-data` user
- **whisper**: Requires `sd-data` user
- **llm_rag**: Creates system directories (may use users role directories list)

---

## Notes

- Role is fully idempotent - safe to run multiple times
- Existing users are not modified unless inventory changes
- Deleting a user from inventory does **not** remove the account (manual cleanup required)
- Groups are created before users to satisfy dependencies
- Home directories are created automatically when users are created
- Lingering is only enabled for non-system users (prevents system account pollution)
