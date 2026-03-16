# Infrastructure Bootstrap with Ansible + Molecule

This repository contains an Ansible-based infrastructure bootstrap used to prepare an Ubuntu server for production use with security hardening, Docker, and basic DevOps tooling.

The configuration is validated through:

- linting
- Molecule tests
- idempotency checks
- post-deploy verification

The goal is to make server provisioning reproducible, safe, and easy to re-run.

---

## Project Goals

This project is designed to provide a reproducible server bootstrap that:

- creates an operational `devops` user
- hardens SSH configuration
- configures a firewall
- installs and configures Fail2ban
- enables automatic security updates
- installs Docker from the official Docker repository
- prepares infrastructure directories

All changes are validated before and after deployment.

---

## What This Project Demonstrates

This repository is intended as a practical infrastructure automation example demonstrating:

- Ansible role-based project structure
- CI/CD integration with GitHub Actions
- Molecule-based role testing
- secure server bootstrap
- post-deploy verification
- idempotent configuration management
- environment-scoped deployment workflow

---

## Repository Structure

```text
.
├── .github/
│   └── workflows/
│       ├── ci.yml
│       └── deploy.yml
├── ansible.cfg
├── fix-yaml.sh
├── group_vars/
│   └── all/
│       └── vault.yml
├── inventory/
│   └── hosts.yml
├── playbooks/
│   ├── bootstrap.yml
│   ├── verify.yml
│   └── files/
│       └── verify_server_remote.sh
├── roles/
│   ├── auto_updates/
│   │   └── tasks/
│   │       └── main.yml
│   ├── common/
│   │   └── tasks/
│   │       └── main.yml
│   ├── directories/
│   │   └── tasks/
│   │       └── main.yml
│   ├── docker/
│   │   ├── molecule/
│   │   │   ├── all_roles/
│   │   │   │   ├── molecule.yml
│   │   │   │   └── verify.yml
│   │   │   └── default/
│   │   │       ├── cleanup.yml
│   │   │       ├── converge.yml
│   │   │       ├── molecule.yml
│   │   │       ├── prepare.yml
│   │   │       ├── side_effect.yml
│   │   │       └── verify.yml
│   │   └── tasks/
│   │       └── main.yml
│   ├── fail2ban/
│   │   └── tasks/
│   │       └── main.yml
│   ├── firewall/
│   │   └── tasks/
│   │       └── main.yml
│   ├── ssh_hardening/
│   │   └── tasks/
│   │       └── main.yml
│   └── users/
│       └── tasks/
│           └── main.yml
├── verify_server_molecule.sh
└── README.md
```

---

## Roles

### `common`

Base/common placeholder role for shared bootstrap tasks.

### `users`

Creates the `devops` user and configures SSH access.

### `ssh_hardening`

Hardens SSH configuration by:

- disabling root login
- disabling password authentication

### `firewall`

Installs and configures UFW.

### `fail2ban`

Installs and enables Fail2ban.

### `auto_updates`

Installs and enables unattended upgrades.

### `docker`

Installs Docker from Docker’s official APT repository using modern `keyrings` and `docker.sources`.

### `directories`

Creates standard infrastructure directories:

- `/opt/docker`
- `/opt/docker/stacks`
- `/opt/backups`
- `/opt/logs`

---

## Secrets and Vault

### 1. Ansible Vault

Sensitive data such as SSH public keys and become password are stored in:

```text
group_vars/all/vault.yml
```

Encrypt locally:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

Edit encrypted values later:

```bash
ansible-vault edit group_vars/all/vault.yml
```

The vault password must never be committed to the repository.

### 2. GitHub Environment Secrets

The deploy workflow expects these secrets:

- `SERVER_IP`
- `SERVER_USER`
- `BOOTSTRAP_SSH_KEY`
- `ANSIBLE_VAULT_PASSWORD`
- `DEVOPS_PUBLIC_KEY`
- `SERVER_SUDO_PASSWORD`

These secrets should be stored in the deployment environment used by the GitHub Actions workflow.

---

## CI/CD

### CI workflow

The CI workflow runs on GitHub-hosted runners and includes:

- `yamllint`
- `ansible-lint`
- security linting
- Ansible syntax validation
- Molecule tests

This workflow runs automatically on:

- push to `master`
- pull requests

### Deploy workflow

Deployment is handled in a separate manual workflow.

It performs:

1. checkout
2. Python and Ansible setup
3. SSH key preparation
4. temporary inventory creation
5. temporary vault creation
6. bootstrap playbook execution
7. idempotency check
8. verification playbook execution
9. cleanup

This workflow runs only through:

- `workflow_dispatch`

and is restricted to the `master` branch.

---

## Molecule Testing

Molecule is used for automated role and integration testing inside Docker containers.

The project currently includes two Molecule scenarios:

- `default` — isolated test for the `docker` role
- `all_roles` — integration test for the full bootstrap playbook

Typical local runs:

```bash
cd roles/docker
molecule test -s default --destroy=always
molecule test -s all_roles --destroy=always
```

Molecule covers:

- container creation
- role application
- idempotency validation
- verification
- cleanup

This provides two levels of validation:

- role-level testing for Docker setup
- end-to-end integration testing for the full server bootstrap

---

## Verification

The project includes a dedicated verification script executed via `playbooks/verify.yml`.

It validates:

- `devops` user existence
- SSH hardening settings
- automatic security updates
- infrastructure directories
- Docker installation and daemon state
- Fail2ban installation and runtime state
- UFW firewall status and allowed ports

Example output:

```text
VERIFY SERVER CONFIGURATION

✅ User devops exists
✅ Root login disabled
✅ Password authentication disabled
✅ Docker installed
✅ Firewall enabled
```

### Verification note

The project intentionally uses two verification approaches:

- **Production verification** copies a verification script to the remote host and executes it there.
- **Molecule verification** runs a separate script directly from the bind-mounted project directory inside the test container.

This demonstrates both remote-host validation and container-based validation using mounted project files.

---

## Idempotency

Idempotency is validated after deployment by running the bootstrap playbook again in check mode.

Example:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --become --check --ask-vault-pass
```

Expected result after initial provisioning:

- `changed=0`
- `failed=0`

This ensures the playbook can be re-run safely without introducing unnecessary changes.

---

## Requirements

### Control host

- Linux / Ubuntu
- Python 3.12+
- Ansible Core
- SSH access to the target host

### Target host

- Ubuntu Server
- reachable over SSH
- user with sudo privileges

---

## Running Locally

### 1. Install Python and create a virtual environment

Make sure Python 3 and `venv` are installed on the control host.

For Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv
```

Create and activate a virtual environment:

```bash
python3 -m venv ansible-venv
source ansible-venv/bin/activate
```

### 2. Install dependencies

```bash
python -m pip install --upgrade pip
pip install ansible-core ansible-lint yamllint molecule molecule-docker docker
ansible-galaxy collection install ansible.posix community.general community.docker
```

Make sure Docker is installed and running on the control host before executing Molecule scenarios.

You can verify the local setup with:

```bash
python --version
ansible --version
molecule --version
docker info
```

### 3. Optional: run the formatting helper script

The repository includes a helper script in the project root:

```text
fix-yaml.sh
```

It can be used locally before running lint checks to normalize YAML formatting, ensure files end with a newline, and apply the expected executable permissions.

Make it executable if needed:

```bash
chmod +x fix-yaml.sh
```

Run it from the repository root:

```bash
./fix-yaml.sh
```

### 4. Create inventory

For manual runs, create:

```text
inventory/hosts.yml
```

Example:

```yaml
all:
  children:
    servers:
      hosts:
        prod:
          ansible_host: 1.2.3.4
          ansible_user: devops
```

Or in INI format:

```ini
[servers]
prod ansible_host=1.2.3.4 ansible_user=devops
```

### 5. Create vault file

Example `group_vars/all/vault.yml`:

```yaml
devops_ssh_key: "ssh-ed25519 AAAA..."
ansible_become_password: "your_sudo_password"
```

Encrypt it:

```bash
ansible-vault encrypt group_vars/all/vault.yml
```

### 6. Configure local vault password file

If you want local `ansible-lint` and syntax checks to work with an encrypted vault file, create a local vault password file:

```bash
mkdir -p ~/.ansible
printf '%s\n' 'your_vault_password' > ~/.ansible/vault_pass.txt
chmod 600 ~/.ansible/vault_pass.txt
```

Then export it before running lint or local checks:

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/.ansible/vault_pass.txt
```

### 7. Test connectivity

```bash
ansible all -i inventory/hosts.yml -m ping --ask-vault-pass
```

Expected result:

```json
prod | SUCCESS => {
  "ping": "pong"
}
```

### 8. Run syntax check locally

```bash
ansible-playbook playbooks/bootstrap.yml --syntax-check -i inventory/hosts.yml --ask-vault-pass
```

### 9. Run lint locally

```bash
yamllint .
ansible-lint
ansible-lint -t security roles/
```

If you use an encrypted vault file locally, make sure `ANSIBLE_VAULT_PASSWORD_FILE` is exported before running `ansible-lint`.

### 10. Run bootstrap locally

```bash
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --ask-vault-pass --become
```

### 11. Run idempotency check locally

```bash
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml --ask-vault-pass --become --check
```

Expected result after successful provisioning:

- no failures
- no unintended changes

### 12. Run verification locally

The verification playbook runs with `become: true`, so local execution requires both the vault password and the sudo password prompt:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/verify.yml --ask-vault-pass --ask-become-pass --become
```

This differs slightly from the local bootstrap command because `playbooks/verify.yml` uses privilege escalation directly during verification and therefore requires an explicit local become password prompt.

### 13. Run Molecule locally

Make sure your user has access to Docker before running Molecule. If needed, add the current user to the `docker` group:

```bash
sudo usermod -aG docker $USER
newgrp docker
docker info
```

On some local environments with `ansible-core 2.20+`, Molecule may also require the broken conditionals compatibility flag because of the current `molecule-docker` behavior:

```bash
export ANSIBLE_ALLOW_BROKEN_CONDITIONALS=True
```

Then run the Molecule scenarios:

```bash
cd roles/docker
molecule test -s default --destroy=always
molecule test -s all_roles --destroy=always
```

---

## Local Verification Checklist

If needed, the server can also be checked manually after bootstrap:

```bash
id devops
grep '^PermitRootLogin no' /etc/ssh/sshd_config
grep '^PasswordAuthentication no' /etc/ssh/sshd_config
systemctl status docker
ufw status
fail2ban-client status
ls -ld /opt/docker /opt/docker/stacks /opt/backups /opt/logs
```

---

## Deploying to a Real Server

Once CI and Molecule tests pass, the playbook can be applied to a real server.

### Manual deployment with GitHub Actions

1. Open the repository
2. Go to **Actions**
3. Select the **Deploy** workflow
4. Click **Run workflow**
5. Choose the `master` branch
6. Start the deployment

The workflow then:

- runs bootstrap
- checks idempotency
- verifies server configuration

---

## SSH Hardening Notes

The SSH hardening role disables:

- root SSH login
- password authentication

To avoid losing access, the bootstrap process is designed to:

- create the `devops` user
- install the configured SSH key
- ensure the user has sudo privileges
- apply SSH hardening only after access is in place

In the current setup, privileged operations still require a sudo password.
If these prerequisites are not met, applying SSH hardening may lock you out of the server.

---

## Security Notes

This repository uses:

- SSH key-based authentication
- disabled SSH password authentication
- disabled root SSH login
- UFW firewall rules
- Fail2ban
- unattended upgrades

Deployment is manual and environment-scoped to reduce operational risk.

---

## Example Development Flow

```text
Local development
      ↓
Git push
      ↓
GitHub Actions CI
      ↓
Lint + syntax check
      ↓
Molecule tests
      ↓
Manual deploy
      ↓
Idempotency check
      ↓
Post-deploy verification
```

---

## Example Production Flow

```text
Run deploy workflow
      ↓
Bootstrap server
      ↓
Re-run playbook in check mode
      ↓
Verify resulting configuration
```

---

## Summary

This project demonstrates a practical infrastructure-as-code workflow where:

- changes are validated before deployment
- deployment is controlled and manual
- server state is verified after provisioning
- configuration remains idempotent on repeated runs

It is intended as a realistic DevOps/Infrastructure automation example rather than just a minimal Ansible demo.

---

## Future Improvements

Possible next steps:

- multi-environment inventories
- automatic staging deployments
- monitoring and logging stack bootstrap
- backup automation
- secret rotation strategy
- additional verification scenarios