# `podman` Role

Configures rootless Podman container runtime with systemd socket activation and per-user configurations. Enables unprivileged users to run containers without root access.

---

## Purpose

The `podman` role provides containerization infrastructure:

| Component | Description |
|-----------|-------------|
| **Podman** | Daemonless container engine compatible with Docker CLI |
| **runc** | OCI-compliant container runtime |
| **podman-compose** | Docker Compose compatibility layer for Podman |
| **Rootless Configuration** | Per-user container namespaces and configs |
| **Systemd Socket** | Activation for rootless Podman API |
| **User Configs** | Per-user containers.conf for customization |

---

## Variables

The role uses the global `users` list from inventory. No role-specific variables required.

**User Configuration** (from inventory):

```yaml
users:
  - name: sd-data
    enable_podman: true          # Enables Podman config for this user
    service_group: sd-data
    # ... other user attributes
```

When `enable_podman: true`, the role:
- Creates `~/.config/containers/` directory
- Writes user-specific `containers.conf`
- Enables systemd lingering for rootless containers

---

## Role Workflow

### 1. System Package Installation
Installs required packages:
- `podman` - Container engine
- `runc` - Container runtime
- `python3-pip` - For podman-compose installation

### 2. podman-compose Installation
Installs podman-compose via pip3 for Docker Compose compatibility:
```bash
pip3 install podman-compose
```

### 3. containers.conf.d Directory
Creates `/etc/containers/containers.conf.d/` for drop-in configuration files:
- Owned by `root:root`
- Mode `0755`
- Used by other roles (e.g., `nvidia`, `llm_rag`) for runtime configs

### 4. Systemd Socket Activation
Enables and starts `podman.socket`:
- Provides Podman API endpoint at `/run/user/UID/podman/podman.sock`
- Allows tools like podman-compose to communicate with Podman daemon-style
- Auto-starts on socket access (systemd activation)

### 5. Per-User Configuration
For each user with `enable_podman: true`:

**Creates directory**:
```bash
mkdir -p /home/USERNAME/.config/containers
chown USERNAME:GROUP /home/USERNAME/.config/containers
chmod 0700
```

**Writes containers.conf**:
```ini
[engine]
events_logger = "journald"
runtime = "runc"
```
- Owned by user:group
- Mode `0644`
- Overrides system defaults for that user

---

## Prerequisites

- **Users Created**: `users` role must run first to create accounts
- **Python**: Python 3.x from `base` role for pip3
- **Systemd**: Systemd-based init system (standard on RHEL 9)

---

## Usage

### Standalone Execution

```bash
ansible-playbook playbooks/podman.yml --ask-become-pass
```

### Verify Installation

```bash
# Check Podman version
podman version

# Verify socket is active
systemctl --user status podman.socket

# Test rootless container
podman run --rm docker.io/hello-world
```

---

## Rootless Podman Usage

### As Regular User

```bash
# No sudo required for rootless containers
podman run -d --name nginx -p 8080:80 docker.io/nginx:alpine

# List containers
podman ps

# View logs
podman logs nginx

# Stop and remove
podman stop nginx
podman rm nginx
```

### With podman-compose

```yaml
# docker-compose.yml
version: '3'
services:
  web:
    image: nginx:alpine
    ports:
      - "8080:80"
```

```bash
# Start services
podman-compose up -d

# View logs
podman-compose logs

# Stop services
podman-compose down
```

---

## User Configuration Customization

The default `containers.conf` uses `runc` runtime and journald logging. To customize per user:

### Add Custom Registry

```bash
# Edit user config
vim ~/.config/containers/registries.conf

[registries.search]
registries = ['docker.io', 'quay.io', 'registry.redhat.io']

[registries.insecure]
registries = ['localhost:5000']
```

### Change Storage Location

```bash
# Edit storage.conf
vim ~/.config/containers/storage.conf

[storage]
driver = "overlay"
graphroot = "/mnt/storage/containers"
```

### Configure Resource Limits

```bash
# Edit containers.conf
vim ~/.config/containers/containers.conf

[containers]
default_ulimits = [
  "nofile=65536:65536",
]
pids_limit = 2048
```

---

## Podman Pod Usage (Multi-Container Groups)

### Create a Pod

```bash
# Create pod with published ports
podman pod create --name myapp -p 8080:80

# Add containers to pod
podman run -d --pod myapp --name web nginx:alpine
podman run -d --pod myapp --name cache redis:alpine

# All containers share network namespace
# web can reach redis at localhost:6379
```

### Manage Pods

```bash
# List pods
podman pod ps

# View containers in pod
podman ps --pod

# Stop entire pod
podman pod stop myapp

# Remove pod (stops and removes all containers)
podman pod rm -f myapp
```

**Example from llm_rag role**:
The RAG stack uses a pod to keep Postgres and Flask service on shared network:
```bash
podman pod create --name rag-stack -p 127.0.0.1:19090:8090
podman run -d --pod rag-stack --name postgres ...
podman run -d --pod rag-stack --name rag_service ...
```

---

## Systemd Integration

### User Service with Podman

Create a systemd user service for auto-starting containers:

```bash
# Generate systemd unit
podman run -d --name myapp nginx:alpine
podman generate systemd --new --name myapp > ~/.config/systemd/user/myapp.service

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now myapp.service

# View status
systemctl --user status myapp.service
```

### Container Auto-Start on Boot

Requires lingering enabled (handled by `users` role):
```bash
# Check lingering status
loginctl show-user sd-data | grep Linger

# Expected: Linger=yes
```

---

## Troubleshooting

### podman-compose Not Found

**Symptom**: `command not found: podman-compose`

**Debug**:
```bash
which podman-compose
pip3 list | grep podman-compose
```

**Solution**:
```bash
# Reinstall via pip
sudo pip3 install --upgrade podman-compose

# Or use system package (if available)
sudo dnf install podman-compose
```

### Permission Denied on Socket

**Symptom**: `Error: unable to connect to Podman socket`

**Debug**:
```bash
# Check socket status
systemctl --user status podman.socket

# Verify socket file exists
ls -la /run/user/$(id -u)/podman/podman.sock
```

**Solution**:
```bash
# Restart socket
systemctl --user restart podman.socket

# Enable lingering (should be done by users role)
sudo loginctl enable-linger $USER
```

### Rootless Port Binding < 1024

**Symptom**: Cannot bind to privileged ports (e.g., port 80).

**Explanation**: Rootless containers can't bind to ports below 1024 without special configuration.

**Solutions**:

**Option 1 - Use unprivileged ports**:
```bash
# Bind to 8080 instead of 80
podman run -p 8080:80 nginx
```

**Option 2 - Enable unprivileged port binding** (system-wide):
```bash
# Allow ports down to 80
sudo sysctl net.ipv4.ip_unprivileged_port_start=80

# Persist across reboots
echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/99-unprivileged-ports.conf
```

**Option 3 - Use systemd socket activation**:
```bash
# Let systemd bind port 80, pass to container
# (Advanced, requires custom systemd unit)
```

### Storage Space Issues

**Symptom**: "No space left on device" when pulling images.

**Debug**:
```bash
# Check storage usage
podman system df

# Check storage location
podman info | grep -A 5 graphRoot
df -h $(podman info --format '{{.Store.GraphRoot}}')
```

**Solution**:
```bash
# Clean up unused resources
podman system prune -a

# Remove specific images
podman image rm IMAGE_ID

# Change storage location (edit ~/.config/containers/storage.conf)
```

### Container Networking Issues

**Symptom**: Containers can't reach internet or each other.

**Debug**:
```bash
# Check network list
podman network ls

# Inspect default network
podman network inspect podman

# Test connectivity
podman run --rm alpine ping -c 3 google.com
```

**Solution**:
```bash
# Recreate default network
podman network rm podman
podman network create podman

# Or create custom network
podman network create mynet
podman run --network mynet ...
```

---

## Podman vs Docker

| Feature | Podman | Docker |
|---------|--------|--------|
| **Daemon** | Daemonless (fork-exec) | Requires dockerd daemon |
| **Root Required** | No (rootless by default) | Yes (or complex rootless setup) |
| **systemd Integration** | Native | Via docker.service |
| **CLI Compatibility** | `alias docker=podman` works | N/A |
| **Pods** | Native support | Requires Kubernetes |
| **Security** | Rootless, no daemon attack surface | Daemon runs as root |

**Migration from Docker**:
Most Docker commands work with Podman:
```bash
alias docker=podman
docker run ...
docker build ...
docker-compose ... # Use podman-compose instead
```

---

## Security Considerations

### Rootless Benefits
- Containers run as non-root user (UID mapped to high range)
- No privileged daemon listening on socket
- Container escape only affects user namespace, not host

### User Namespace Mapping
```bash
# Check UID mapping
podman unshare cat /proc/self/uid_map
# Example output:
#          0       1000          1  (container root = host UID 1000)
#          1     100000      65536  (container UIDs 1-65536 = host 100000-165535)
```

Files created by container root appear as owned by the user on the host.

### SELinux Compatibility
Podman respects SELinux labels by default:
```bash
# Run with SELinux label
podman run --security-opt label=type:container_runtime_t ...

# Disable labeling (used by llm_rag for /srv volumes)
podman run --security-opt label=disable ...
```

---

## Integration with Other Roles

### nvidia Role
Adds NVIDIA runtime configuration:
```ini
# /etc/containers/containers.conf.d/nvidia.conf
[engine]
runtime = "nvidia"
```

Allows GPU access:
```bash
podman run --device nvidia.com/gpu=all nvidia/cuda:12.1.0-base nvidia-smi
```

### llm_rag Role
Uses crun runtime for better SELinux compatibility:
```ini
# /etc/containers/containers.conf.d/zz-llm-rag-runtime.conf
[engine]
runtime = "crun"
```

Creates pods for multi-container stacks:
```bash
podman pod create --name rag-stack -p 127.0.0.1:19090:8090
```

### users Role Dependency
The `users` role must run first to:
- Create user accounts
- Enable systemd lingering
- Set up home directories

The `podman` role then iterates over users with `enable_podman: true`.

---

## Advanced Usage

### Quadlet (systemd Generator)

Podman 4+ supports Quadlet for declarative systemd units:

```ini
# ~/.config/containers/systemd/myapp.container
[Container]
Image=nginx:alpine
PublishPort=8080:80

[Service]
Restart=always

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user start myapp.service
```

### Remote Podman

Access Podman API remotely:
```bash
# On host: enable socket
systemctl --user start podman.socket

# On client: connect via SSH tunnel
ssh -L 8888:/run/user/1000/podman/podman.sock user@host

# Use remote connection
export CONTAINER_HOST=unix:///tmp/podman.sock
podman --remote ps
```

---

## Related Roles

- **users**: Must create accounts before Podman config
- **nvidia**: Adds GPU runtime support
- **llm_rag**: Uses Podman for RAG stack deployment
- **base**: Provides Python for podman-compose installation
