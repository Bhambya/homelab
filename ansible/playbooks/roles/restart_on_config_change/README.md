# restart_on_config_change

Ansible role that restarts Docker Compose services whose config files changed in the latest `git pull` of the homelab repo.

Some config changes only take effect after a container restart: single-file bind mounts keep pointing at the old inode after git replaces the file, and some services (e.g. authelia) copy their config into place on start. `docker compose up` does not recreate containers for these changes, so this role restarts them explicitly.

## Requirements

- The `community.docker` collection
- The repo checked out on the target host with `ansible.builtin.git`, with the result registered

## Role Variables

- `repo_path` (required): Path of the repo checkout on the target host
- `repo_update` (required): Registered result of the `ansible.builtin.git` task (uses its `before` and `after` commits)
- `compose_project_src` (required): Directory containing the `compose.yml`
- `restart_on_change` (optional): List of `path`/`service` entries, defaults to `[]`
  - `path`: Path relative to the repo root. A file path matches that file; a path ending in `/` matches everything under that directory
  - `service`: Compose service to restart when a matching file changed
- `compose_wait_timeout` (optional): Seconds to wait for restarted services to be healthy, defaults to `300`

## Dependencies

None

## Example Usage

```yaml
- name: Ensure repo is in clean state
  ansible.builtin.git:
    repo: 'https://github.com/Bhambya/homelab.git'
    dest: "{{ repo_path }}"
    version: 'main'
  register: repo_update

# ... docker compose up ...

- name: Restart services whose config changed
  ansible.builtin.include_role:
    name: restart_on_config_change
  vars:
    compose_project_src: "{{ host_conf_path }}/docker"
    restart_on_change:
      - path: "hosts/vps/docker/traefik/config/dynamic.yml"
        service: traefik
      - path: "hosts/vps/docker/crowdsec/"
        service: crowdsec
```

## Behavior

1. **Change Detection**: Runs `git diff --name-only` between the commits before and after the pull
2. **Matching**: Collects each service with at least one changed file under its `path`, restarting each service once
3. **Restart**: Restarts the matched services with `docker compose restart` and waits for them to be healthy
4. **Logging**: Prints which services were restarted, or that none were

On a fresh clone (no previous commit) or when the pull brought no new commits, nothing is restarted.
