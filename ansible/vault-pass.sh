#!/bin/sh
# Ansible vault password client: CI passes the password via env, locally it is
# read from the macOS keychain. Store it once with:
#   security add-generic-password -a homelab -s ansible-vault -w
if [ -n "$ANSIBLE_VAULT_PASSWORD" ]; then
  printf '%s\n' "$ANSIBLE_VAULT_PASSWORD"
else
  security find-generic-password -a homelab -s ansible-vault -w
fi
