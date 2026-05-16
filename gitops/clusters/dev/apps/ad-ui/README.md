# ad-ui

LDAP Account Manager for Samba Active Directory user and group administration.

This app expects a Kubernetes Secret named `ad-ui-secrets` in the `ad-ui` namespace. Create or refresh it from the platform control machine:

```bash
cd platform/ansible
ansible-playbook playbooks/configure-ad-ui-secret.yml -i inventory/dev.ini
```

The UI is exposed at:

```text
https://ad.dev.w237.local/
```