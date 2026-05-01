# Trial Setup - Docker Compose

## Prerequisites

- [Docker Desktop](https://docs.docker.com/desktop/)
- Clone this repository

## Setup

**1. Change directory**

```bash
cd setup-trial-docker-compose
```

**2. Start**

```bash
docker compose up
```

The first run downloads the image, creates a new site, and installs apps - this may take up to 10 minutes.

Wait for:

```
WARNING: This is a development server. Do not use it in a production deployment. Use a production WSGI server instead.
Running on all addresses (0.0.0.0)
Running on http://127.0.0.1:8000
```

Site is then available at `http://localhost:8000`.

Default credentials: username `Administrator`, password `12345`.

**3. Managing**

- To stop: `Ctrl + C` or `docker compose down`
- To start again: `docker compose up`
- To remove: `docker compose down -v`

## Notes

- Not intended for production use.
