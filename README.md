# docker-synapse-server

Matrix homeserver (Synapse) for the Deploy App integration stack.

## DNS records required

These public DNS records must point to your WAN address:

- `synapse.domain` — Matrix homeserver; Element clients connect here and federation traffic arrives here
- `mas.domain` — Matrix Authentication Service; clients are redirected here to log in
- `matrix.domain` — Deploy App Matrix integration UI/API (matrixrmapi)
- `mtls.matrix.domain` — mTLS access to the matrix integration API

## Environment variables

### Required

| Variable                      | Description                                                                                              |
| ----------------------------- | -------------------------------------------------------------------------------------------------------- |
| `SYNAPSE_DATABASE_PASSWORD`   | PostgreSQL password for the `synapse` database                                                           |
| `SYNAPSE_MACAROON_SECRET_KEY` | Secret used to sign Synapse macaroon tokens. Generate with `openssl rand -hex 32`                        |
| `MAS_SYNAPSE_SECRET`          | Shared secret between Synapse and MAS for delegated authentication. Generate with `openssl rand -hex 32` |

### Optional

| Variable               | Default           | Description                              |
| ---------------------- | ----------------- | ---------------------------------------- |
| `SYNAPSE_BOT_USERNAME` | `matrixrmapi-bot` | Local part of the Synapse admin bot user |
| `SYNAPSE_FEDERATION`   | `*`               | Federation mode (see below)              |

### Federation modes

`SYNAPSE_FEDERATION` controls server-to-server federation:

```
SYNAPSE_FEDERATION="*"                   # open — federate with any Matrix server (default)
SYNAPSE_FEDERATION="off"                 # disabled — no server-to-server traffic at all
SYNAPSE_FEDERATION="pvarki.fi,ally.org"  # allowlist — only the listed domains
```

### Database variables (set automatically from the compose stack)

| Variable        | Description              |
| --------------- | ------------------------ |
| `POSTGRES_HOST` | PostgreSQL hostname      |
| `POSTGRES_USER` | PostgreSQL user          |
| `POSTGRES_DB`   | PostgreSQL database name |

## Rooms and spaces created automatically

On first startup, matrixrmapi creates a Space and four rooms scoped to the deployment:

| Key      | Alias pattern                     | Purpose                              |
| -------- | --------------------------------- | ------------------------------------ |
| space    | `#<deployment>-space:<domain>`    | Top-level Space; all users auto-join |
| general  | `#<deployment>-general:<domain>`  | General work discussion              |
| helpdesk | `#<deployment>-helpdesk:<domain>` | Issue reporting and help             |
| offtopic | `#<deployment>-offtopic:<domain>` | Off-topic conversation               |
| admin    | `#<deployment>-admin:<domain>`    | Admin-only channel                   |

All rooms use end-to-end encryption and restricted join rules (Space membership required).
Admins promoted in Deploy App receive power level 100 and are joined to the admin channel automatically.

## Versioning

Versioning is handled with [bump-my-version](https://github.com/callowayproject/bump-my-version). To increment, use `bump-my-version bump <patch/minor/major>`.

You can use `bump-my-version show-bump` to see how each option would affect the version.
