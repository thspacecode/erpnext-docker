# erpnext-docker

Custom [ERPNext](https://erpnext.com/) Docker images and ready-to-run deployment recipes, maintained by [SpaceCode](https://spacecode.co.th/).

The images pre-bake `bench init` and the Frappe/ERPNext install on top of `frappe/build`, so they can be reused as a **builder stage** for your own custom-app images — without repeating the slow bench bootstrap on every build.

> 📖 Background and design rationale: **[Understanding ERPNext Docker images](https://spacecode.co.th/en/knowledge-base/p/erpnext-docker)**

Images are published to Docker Hub: **[`thspacecode/erpnext-docker`](https://hub.docker.com/r/thspacecode/erpnext-docker)**

---

## Why a custom image?

Frappe ships official images (`frappe/base`, `frappe/build`, `frappe/erpnext`), and the standard way to build a custom app is a multi-stage Dockerfile that, on every build, runs `bench init` and re-installs Frappe + ERPNext before adding your app. That bootstrap is the slow part.

This project moves that work into a reusable, version-tagged base image:

- **Faster custom-app builds** — `bench init` + Frappe/ERPNext are already baked in. Your build only adds your app and compiles assets.
- **Version clarity** — a pinned tag tells you exactly which Frappe and ERPNext versions you are building on.

**Trade-off:** because it keeps the build dependencies, the base image is ~1 GB (vs. the official ~500 MB runtime image). Since it is meant to be consumed as a *builder stage* in a multi-stage build, your final production image stays just as small.

---

## Image variants

A single multi-stage [`dockerfile/Dockerfile`](dockerfile/Dockerfile) produces three chained images, each published under its own tag:

| Target        | Docker Hub tag             | What's inside                                                                 | Use it for                                                        |
| ------------- | -------------------------- | ---------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| `base`        | `version-16-latest`        | `frappe/build` + `bench init` + ERPNext, pre-baked                            | Builder stage for custom apps; the trial & dev Compose setups      |
| `all-in-one`  | `ALL-version-16-latest`    | `base` + MariaDB, Redis, nginx, supervisor — site is created on **first boot** | Single-container trials, Railway (sleepable), Dokploy previews     |
| `pre-install` | `PRE-version-16-latest`    | `all-in-one`, but the site + ERPNext are created at **build time**             | Demos, previews & agentic / ephemeral workflows (instant boot)    |

Each variant also gets an immutable, version-pinned tag derived from the actual installed versions, e.g. `16-F<frappe>.<x>_E<erpnext>.<y>` (and the `ALL-` / `PRE-` prefixed equivalents).

> **Tip — agentic & ephemeral workflows:** the `pre-install` image already contains a created site with ERPNext installed, so a container boots into a ready instance in seconds — no site creation or app install on first run. That makes it a great fit for agentic or CI pipelines that spin up a throwaway ERPNext on demand: the agent only has to `bench get-app` its custom app on top and start working.

---

## Quick start

The fastest way to see ERPNext running:

```bash
git clone https://github.com/thspacecode/erpnext-docker.git
cd erpnext-docker/setup-trial-docker-compose
docker compose up
```

First boot creates the site and installs apps (up to ~10 minutes). Then open <http://localhost:8000> and log in as `Administrator` / `12345`.

See [`setup-trial-docker-compose/README.md`](setup-trial-docker-compose/README.md) for details.

---

## Deployment setups

Each folder is self-contained and has its own step-by-step README.

| Setup           | Folder                                                            | Best for                                                  |
| --------------- | ---------------------------------------------------------------- | --------------------------------------------------------- |
| **Trial**       | [`setup-trial-docker-compose`](setup-trial-docker-compose/)       | Trying ERPNext quickly on Docker Compose                  |
| **Development** | [`setup-dev-docker-compose`](setup-dev-docker-compose/)           | Building custom Frappe apps in a VS Code Dev Container    |
| **Production**  | [`setup-prod-docker-compose`](setup-prod-docker-compose/)         | Self-hosting with the services split into containers      |
| **Railway**     | [`setup-railway-separated`](setup-railway-separated/)             | One-click cloud hosting on [Railway](https://railway.app/) |

- **Trial** and **Production** run the `base` image alongside dedicated MariaDB and Redis containers.
- **Production** splits the stack into web (gunicorn), websocket, short/long workers, scheduler, nginx, MariaDB and Redis, and serves on port 80 — put a reverse proxy (Traefik, Caddy, …) in front for TLS.
- **Railway** layers supervisor + nginx onto the `base` image and runs the Frappe services together, because Railway currently allows only one service per volume.

---

## Building the images yourself

Build any target from the `dockerfile/` directory with `--target`:

```bash
cd dockerfile

# Base (builder) image
docker buildx build --target base -t erpnext-docker:version-16-latest .

# All-in-one (DB + Redis + nginx + supervisor, site created on first boot)
docker buildx build --target all-in-one -t erpnext-docker:ALL-version-16-latest .

# Pre-install (site + ERPNext baked at build time)
docker buildx build --target pre-install -t erpnext-docker:PRE-version-16-latest .
```

The Frappe/ERPNext branch and repos are configurable via build args (`FRAPPE_BRANCH`, `FRAPPE_REPO`, `ERPNEXT_BRANCH`, `ERPNEXT_REPO`). The `pre-install` target additionally accepts `SITE_NAME`, `ADMIN_PASSWORD` and `DB_ROOT_PASSWORD`.

### Using `base` as a builder stage for a custom app

```dockerfile
# Reuse the pre-baked bench + ERPNext
FROM thspacecode/erpnext-docker:version-16-latest AS builder
WORKDIR /home/frappe/frappe-bench
RUN bench get-app --resolve-deps https://github.com/your-org/your_app

# ...then copy the built bench into a slim runtime image (e.g. frappe/base)
```

---

## Continuous integration

[`.github/workflows/push-docker.yml`](.github/workflows/push-docker.yml) runs on every push to `main` and weekly (Sunday 00:00). It:

1. Builds the `base` target.
2. Smoke-tests it with the trial Compose stack — waits for the site and asserts an HTTP `200`.
3. Reads the installed versions via `bench version` and computes the version tag.
4. Builds and pushes `base`, `all-in-one` and `pre-install` to Docker Hub with both `latest` and version-pinned tags.

---

## Repository layout

```
.
├── dockerfile/                   # Source for the published images
│   ├── Dockerfile                #   single multi-stage build (base → all-in-one → pre-install)
│   ├── base/conf/                #   scripts baked into the base image (→ frappe-bench/cmd)
│   ├── all-in-one/conf/          #   setup.sh + nginx.conf + supervisord.conf
│   └── pre-install/conf/         #   init.sh (build-time setup) + start.sh (runtime entrypoint)
├── setup-trial-docker-compose/   # One-command trial on Docker Compose
├── setup-dev-docker-compose/     # VS Code Dev Container for app development
├── setup-prod-docker-compose/    # Multi-container production stack
├── setup-railway-separated/      # Deploy to Railway
└── .github/workflows/            # Build, smoke-test, tag & push to Docker Hub
```

---

## References

- [Understanding ERPNext Docker images](https://spacecode.co.th/en/knowledge-base/p/erpnext-docker) — the article this repo accompanies
- [Frappe / ERPNext system architecture](https://spacecode.co.th/knowledge-base/p/erpnext-system-architect)
- [Official `frappe_docker`](https://github.com/frappe/frappe_docker)
- [ERPNext](https://erpnext.com/) · [Frappe Framework](https://frappe.io/)
