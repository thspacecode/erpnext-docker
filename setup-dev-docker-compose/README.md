# Development Setup - Docker Compose

## Prerequisites

- [Docker Desktop](https://docs.docker.com/desktop/)
- [Visual Studio Code](https://code.visualstudio.com/download)
- Clone this repository

## Setup

**1. Open in Dev Container**

Open Command Palette (`Ctrl + Shift + P`) and run `Dev Containers: Open Folder in Container`, then select the `setup-dev-docker-compose` folder.

**2. Initialize bench**

Open terminal your path should be on `/workspace/frappe-bench`

```bash
../.devcontainer/init-bench.sh
```

**3. Start development server**

```bash
bench start
```

## Notes

- Site is available at `http://localhost:8000`.
- Default credentials: username `Administrator`, password `12345`.
- Developer mode is enabled by default.
