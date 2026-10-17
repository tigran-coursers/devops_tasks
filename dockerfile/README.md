# Dockerfile - Step By Step Guide

## The Idea

An **image** is built from a recipe. The recipe is a text file called **Dockerfile**. In this module you write Dockerfiles for a small Java web server, from a first simple one to a professional one.

```text
Dockerfile  ──docker build──►  image  ──docker run──►  container
 (recipe)                      (frozen meal)           (the meal, served)
```

Every line of a Dockerfile is an **instruction**. Every instruction makes a **layer**, like a layer of a cake. Docker keeps the layers (this is the **cache**), and uses them again when nothing changed. This is why the **order** of the lines matters.

| Instruction | What it does |
|---|---|
| `FROM image` | The image to start from. Every Dockerfile starts with it. |
| `WORKDIR /app` | The folder inside the image where the next lines work. |
| `COPY from to` | Copies files from your computer into the image. |
| `RUN command` | Runs a command **while building** (install, compile ...). |
| `ENV NAME=value` | An environment variable, also available when the container runs. |
| `ARG NAME=value` | A variable that exists **only while building**. |
| `LABEL key=value` | A note stored in the image. |
| `EXPOSE 8080` | Says which port the program uses. (A note. It does not open the port.) |
| `USER name` | Who runs the next lines and the program. |
| `HEALTHCHECK ...` | A command that tells if the program is healthy. |
| `CMD ["a", "b"]` | The command that **starts the program** when the container runs. |

## The Application

`app/src/App.java` is a tiny web server. It has no libraries. You do **not** change it.

```text
GET /        ->  Hello from Docker! greeting=<GREETING variable>
GET /health  ->  OK
GET /whoami  ->  user=<the user that runs the program>
```

## What You Need

- Docker Desktop (it must be **running**)
- macOS or Linux (on Windows use WSL), `bash`, `curl`

## How It Works

You write **6 Dockerfiles**, one for each level: `app/Dockerfile.1` ... `app/Dockerfile.6`. Each file has a description with a `TODO`.

Check your work:

```bash
./check.sh        # all 6 levels
./check.sh 3      # only level 3
```

The checker builds your image, starts a container, and tests it. You get `PASS` or `FAIL` with a hint.

To try it by hand:

```bash
cd app
docker build -f Dockerfile.1 -t hello:1 .
docker run --rm -p 8080:8080 hello:1
# in another terminal:   curl http://localhost:8080
```

The checker only touches images and containers named `labcheck-...`, and removes them at the end.

---

## Level 1 - The First Image

Open `app/Dockerfile.1`. Five instructions:

```dockerfile
FROM _____                  # a base image that has Java: eclipse-temurin:21-jdk
WORKDIR _____               # /app
COPY _____ _____            # copy src/App.java into the image
EXPOSE _____                # 8080
CMD ["_____", "_____"]      # java App.java
```

**Exec form or shell form?** `CMD ["java", "App.java"]` (exec form, with brackets) starts your program directly. `CMD java App.java` (shell form) starts a **shell**, and your program is its child. Then `docker stop` talks to the shell, and your program may not get the signal. Use the exec form.

## Level 2 - ENV, ARG, LABEL

Open `app/Dockerfile.2`. Copy your Dockerfile.1, and add three things:

- `ENV GREETING=Welcome`: a default. `docker run -e GREETING=Salut ...` can still change it.
- `ARG APP_VERSION=1.0`: a value that you give when you **build**: `docker build --build-arg APP_VERSION=2.5 ...`
- Two `LABEL` lines. The version label uses the ARG: `LABEL version="$APP_VERSION"`. The `ARG` line must come **before** it.

`ENV` is for the running container, `ARG` is only for the build.

## Level 3 - Layers And The Cache

Open `app/Dockerfile.3`.

Docker builds the lines from top to bottom. When a line (or the files it copies) **changes**, that line and **everything below it** is built again. Everything above comes from the cache.

The script `install-deps.sh` is slow, like a real `mvn dependency:go-offline` or `npm install`. Your source `App.java` changes many times a day. So:

- Things that change **rarely** go on **top**: copy and run the install script.
- Things that change **often** go at the **bottom**: copy the source.

If you copy the source first, every small change runs the slow script again.

How does the checker know? The script writes a random number into `/app/deps-id`. The checker builds, changes `App.java`, builds again, and compares the numbers. The same number means the slow step was **not** run again.

## Level 4 - A Small Build Context

Open `app/.dockerignore`.

When you run `docker build .`, Docker first **sends the whole folder** (the *build context*) to the engine. If there is a 2 GB `node_modules` or a big `junk/` folder, every build is slow, and `COPY . .` puts the junk into your image.

`.dockerignore` works like `.gitignore`: a list of things that are **not** sent. Write the four lines of the TODO. The checker adds a 20 MB junk file and measures how much Docker sends.

## Level 5 - A Safe Image

Open `app/Dockerfile.5`.

**Not root.** By default the program runs as `root`, the most powerful user. If somebody breaks into your web server, they are `root` in the container. Create a normal user and switch to it:

```dockerfile
RUN useradd --create-home app
USER app
```

**Healthcheck.** Docker can run a command every few seconds to ask "are you OK?". If it fails again and again, the container is marked `unhealthy`:

```dockerfile
HEALTHCHECK --interval=5s --timeout=3s --retries=3 CMD curl -f http://localhost:8080/health || exit 1
```

Look at the status with `docker ps` (it shows `(healthy)`).

## Level 6 - Multi-Stage Build

Open `app/Dockerfile.6`.

To **build** a Java program you need the JDK (a big compiler). To **run** it you only need the JRE. With one stage, the compiler stays in your final image for nothing. A multi-stage build uses two `FROM` lines:

```text
stage 1 "build":  JDK  ── compile ──►  app.jar
                                          │ COPY --from=build
stage 2 (final):  JRE  ◄─────────────────┘   only the result, not the compiler
```

Only the **last** stage becomes the image. The checker wants: no `javac` in it, and a size clearly smaller than the plain JDK image (about half).

---

## Common Mistakes

| Problem | Reason |
|---|---|
| `file with no instructions` | The Dockerfile has only comments. Write the TODO lines. |
| `COPY failed: file not found` | The path is relative to the **build context** (the `app` folder), not to the Dockerfile. |
| The slow step runs on every build (level 3) | The source is copied **before** the script. Change the order. |
| The label has no version (level 2) | The `ARG` is **after** the `LABEL`. It must be before. |
| `permission denied` after `USER app` (level 5) | The files belong to root. Copy and run what needs root **before** `USER`, and make sure `app` can read the files. |
| The final image is as big as the JDK image (level 6) | The last stage uses `-jdk`. Use `eclipse-temurin:21-jre`. |

## Rules

- Do not change `app/src/App.java`, `app/scripts/install-deps.sh`, or `check.sh`.
- Write each level in its own file.
