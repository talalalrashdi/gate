# Replaced by System health

The temporary admin diagnostics page and button were removed. Open `/admin/health` and use **Run checks** / **Copy report**. It is always available to super admins and shows English errors with numbered fixes and log reference IDs.

`Diagnostics:Enabled` is no longer used. Empty `Diagnostics:BootstrapAccounts` after first-time setup; it is only a limited fallback when SQL authorization is unavailable, not an override for a denied role.

See [ADMIN_PHASE5.md](../docs/ADMIN_PHASE5.md) for checks, permissions, bootstrap setup, deployment and verification.
