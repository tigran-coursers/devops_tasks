# Docker Compose - Step By Step Guide

## The Idea

A real application is not one container. It is a web server, a database, maybe more. Starting them by hand with many long `docker run` commands is slow and easy to get wrong.

**Docker Compose** lets you describe the **whole application in one file**, and start everything with **one command**:

```bash
docker compose -f compose.1.yml up -d       # start everything
docker compose -f compose.1.yml down        # stop and remove the containers
```

```text
            ┌───────────────  compose.yml  ────────────────┐
 your PC ──►│  web (your Java app)  ──────►  db (PostgreSQL) │
  :8090     └───────────────────────────────────────────────┘
```

The file is written in **YAML**: the structure is made with **spaces** (not tabs!). Look at how much each line is indented.

## The Application

`app/` is a small web application that **counts visits in a PostgreSQL database**:

```text
GET /health  ->  OK
GET /visits  ->  visits=1     (every call adds 1, and the number is stored in the database)
```

Its Dockerfile is **finished** (you wrote Dockerfiles in the module `dockerfile`). Here you write the **compose files**.

The web app needs three environment variables: `DB_URL`, `DB_USER`, `DB_PASSWORD`. When it starts, it tries to connect to the database up to 60 times, and it writes a line for every try: `docker compose logs web` shows them.

## What You Need

- Docker Desktop (it must be **running**)
- macOS or Linux (on Windows use WSL), `bash`, `curl`
- The ports **8090** and **8091** must be free (stop other applications that use them)

## How It Works

You write **5 compose files**, one for each level: `compose.1.yml` ... `compose.5.yml`. Each file starts with a description and a `TODO`. Each level builds on the one before: **copy the previous file, then add the new part.**

```bash
./check.sh        # all 5 levels
./check.sh 3      # only level 3
```

The checker starts your stack, tests it, and stops it. It only uses the project name `labcheck`, and removes everything of that project at the end.

To try it by hand:

```bash
docker compose -f compose.1.yml up -d --build
curl http://localhost:8090/visits
docker compose -f compose.1.yml logs web
docker compose -f compose.1.yml down -v          # -v also removes the volumes
```

---

## Level 1 - Two Services

Open `compose.1.yml`. Replace the `_____`:

```yaml
services:
  web:
    build: ./app                       # build the image from the Dockerfile in ./app
    ports:
      - "8090:8080"                    # host:container
    environment:
      DB_URL: jdbc:postgresql://db:5432/visits
      ...
  db:
    image: postgres:16-alpine
    environment: ...
```

**The most important thing of this level:** the database address is `db`, the **name of the service**. Compose makes a private network, and every service can reach the others **by name**. If you write `localhost`, it does not work: **inside a container, `localhost` is the container itself**.

## Level 2 - A Volume

Run `down` and `up` again: the counter starts at 1 again. The database kept its files **inside the container**, and the container was removed.

A **named volume** lives outside the container. Two steps:

```yaml
services:
  db:
    volumes:
      - dbdata:/var/lib/postgresql/data     # name:folder-inside-the-container

volumes:                                     # at the TOP level, no indentation
  dbdata:
```

`docker compose down` removes the containers but **keeps** the volumes. `down -v` removes the volumes too.

## Level 3 - Settings In .env

The password is written in the compose file, and the compose file goes into git. Now everybody can read it. Settings and secrets go to a **`.env`** file (open it). Compose reads it by itself, and you use the values with `${NAME}`:

```yaml
environment:
  DB_PASSWORD: ${DB_PASSWORD}
ports:
  - "${WEB_PORT}:8080"
```

Tip: `docker compose -f compose.3.yml config` prints your file with all the variables replaced. Use it to see what Compose really understands.

(In a real project the `.env` file is **not** committed. It is here only so you can learn.)

## Level 4 - Start In The Right Order

Look at `docker compose logs web` of level 3. You see `DB not ready (attempt 1)`, `(attempt 2)` ... The web app started **before** the database was ready. This one survives because it retries. Many applications crash.

`depends_on: db` only waits until the db **container has started**, not until PostgreSQL is **ready**. The right way has three parts:

```yaml
db:
  healthcheck:                                 # a command that says "I am ready"
    test: ["CMD-SHELL", "pg_isready -h 127.0.0.1 -U ${DB_USER} -d ${DB_NAME}"]
    interval: 3s
    timeout: 3s
    retries: 10
web:
  depends_on:
    db:
      condition: service_healthy               # wait until the healthcheck says healthy
  restart: unless-stopped                      # start again if it crashes
```

Why `-h 127.0.0.1`? While PostgreSQL prepares its first start, it listens only on a file socket. Without `-h` the check says "ready" too early, and the web app still fails.

The checker wants to see `DB connected (attempt 1)` in the log of web.

## Level 5 - Networks And Profiles

Two improvements:

**Networks.** The database must be reachable only by the web app, not from your computer and not from other services. Use two networks:

```text
frontend ── web ── backend ── db
(the world)                  (private)
```

- `web` is on both: `networks: [frontend, backend]`
- `db` is only on `backend`, and has **no `ports:`** at all

**Profiles.** Adminer is a web page to look inside the database. It is useful for you, but it should start **only when you ask**. Put it in a profile:

```yaml
adminer:
  image: adminer
  profiles: ["tools"]
  ports:
    - "8091:8080"
  networks: [backend]
```

A normal `up` ignores it. This starts it too:

```bash
docker compose -f compose.5.yml --profile tools up -d
```

Open http://localhost:8091 (System: PostgreSQL, Server: `db`, and the user and password from `.env`).

---

## Common Mistakes

| Problem | Reason |
|---|---|
| `yaml: ... mapping values are not allowed` | The indentation is wrong. Use spaces, 2 for each level. |
| The web app says `Connection refused` to `localhost` | Use the **service name** (`db`) as the host. |
| The counter starts at 1 after `down` / `up` | No volume (level 2), or you used `down -v`. |
| `port is already allocated` | Another program uses 8090/8091. Stop it. |
| `variable is not set` warnings | The name in `${...}` is not in `.env`. Check the spelling. |
| `depends_on` seems to do nothing | You need `condition: service_healthy` **and** a `healthcheck` on the db. |
| The healthcheck passes too early | Add `-h 127.0.0.1` to `pg_isready`. |
| Nothing is left after `down -v` | That is what `-v` does: it removes the volumes and the data. |

## Rules

- Do not change `app/`, `.env`, or `check.sh`.
- Write each level in its own file.
