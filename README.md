# DevOps Tasks

This project contains separate practice modules about **DevOps tools**: the tools that package, run and ship software.

Each module is independent and has its own `README.md` guide. You **write** files (Dockerfiles, compose files, commands) and a `check.sh` script **builds and runs** what you wrote, then tells you `PASS` or `FAIL`.

The modules will grow from simple to harder topics:

```text
Docker                 (containers, images, Dockerfile, Compose)
CI/CD                  (a pipeline that builds, tests, packages and deploys on every push)   <- you are here too
Kubernetes             (run many containers on many machines)
Linux and shell        (the command line)
```

## Project Structure

```text
devops_tasks/
├── README.md
├── .gitignore
├── docker-basics/        10 tasks: run, logs, exec, volumes, networks ...
│   ├── README.md
│   ├── tasks.sh          <- you write the docker commands here
│   ├── check.sh
│   └── site/
├── dockerfile/           6 levels: from a first image to a multi-stage build
│   ├── README.md
│   ├── check.sh
│   └── app/              <- you write Dockerfile.1 ... Dockerfile.6 here
├── docker-compose/       5 levels: two services, volumes, .env, healthchecks, networks
│   ├── README.md
│   ├── check.sh
│   ├── .env
│   ├── compose.1.yml ... compose.5.yml   <- you write these
│   └── app/
├── ci-cd/                6 levels: a GitHub Actions pipeline (build, test, package, deploy)
│   ├── README.md
│   └── starter/          <- copy this folder to a NEW GitHub repository
│       ├── .github/workflows/ci.yml      <- you write the pipeline here
│       ├── check.sh
│       ├── pom.xml, Dockerfile
│       └── src/
└── github-pages-release/ 7 levels: publish a frontend site on GitHub Pages, then release it step by step
    ├── README.md
    ├── check.sh          checks your live site, your releases and your pipeline files
    ├── site/             <- a ready website: copy its content to a NEW public repository
    └── workflows/        <- pages.yml and release.yml, with TODOs
```

## Current Modules

```text
docker-basics    - the docker command line: run, logs, exec, env, volumes, networks, limits, clean up
dockerfile       - write Dockerfiles: layers and cache, .dockerignore, non-root, healthcheck, multi-stage
docker-compose   - run an app with a database: volumes, .env, depends_on + healthcheck, networks, profiles
ci-cd            - a GitHub Actions pipeline: trigger on a push to main, build / test / package stages, artifacts,
                   caching, secrets, and an optional deploy to a free server
github-pages-release - put a frontend-only site online for free (GitHub Pages) at a public address, then release it
                   step by step: update, deploy with a pipeline, version tags, releases, automatic releases, rollback
```

Do them in this order. `ci-cd` does not need the Docker modules.

## What You Need

For the three **Docker** modules:

- **Docker Desktop**, installed and **running** (`docker info` must work)
- **macOS or Linux.** On Windows use WSL (Windows Subsystem for Linux)
- `bash` and `curl`
- Internet, to download images the first time (about 1 GB in total)

For the **ci-cd** module (no Docker needed):

- A **GitHub account** and `git`
- JDK 21 and Maven
- `bash` (macOS, Linux, or Git Bash / WSL on Windows)

For the **github-pages-release** module (no Docker, no Java):

- A **GitHub account** (free) and `git`. The repository must be **public** (free GitHub Pages works only for public repositories)
- `bash` and `curl`

## How Your Work Is Checked

Every module has a `check.sh`:

```bash
cd docker-basics
./check.sh          # check everything
./check.sh 3        # check one task or level
```

It prints a line for each check, and what to look at when something fails.

The checkers are careful with your computer: they use only names that start with `lab-` or `labcheck` for the things they create, and remove them at the end. Your own containers, images and volumes are not touched.

Ports used: `8081`, `8082` (docker-basics), `18080` (dockerfile), `8090`, `8091` (docker-compose). Stop other programs that use them.

The `ci-cd` and `github-pages-release` modules are different: the work runs on **GitHub**, not on your computer. Its `check.sh` reads your pipeline file and checks what it says. The real proof is a green run in the **Actions** tab of your repository.

## Notes

- Each module has a step-by-step guide in its own `README.md`.
- The modules are separate and do not share code.
- In a real project a `.env` file with passwords is **not** committed to git. In `docker-compose` it is committed on purpose, to learn.
