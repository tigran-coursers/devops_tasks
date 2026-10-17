# Docker Basics - Step By Step Guide

## The Idea

You have written a program. It works on your computer. You give it to a friend, and it does not work: a different Java version, a missing library, a different operating system. "But it works on my machine!"

**Docker** solves this. It puts your program and everything it needs into one box, and the box runs the same way everywhere.

| Word | What it is | Real life |
|---|---|---|
| **Image** | A read-only package: the program and everything it needs. | A frozen meal in a box. |
| **Container** | A **running** copy of an image. | The meal, heated and served. You can heat many from one box. |
| **Volume** | A folder that **lives outside** the container. | A fridge: when the plate is thrown away, the food in the fridge stays. |
| **Network** | A private road between containers. | A corridor between two rooms of a house. |
| **Registry** | A place where images are kept (Docker Hub). | A supermarket of frozen meals. |

In this module you learn the **commands** to work with containers. You write **10 small tasks**, and a checker looks at what you really did.

## What You Need

- Docker Desktop (it must be **running**)
- macOS or Linux (on Windows use WSL)
- `bash` and `curl`

## How It Works

1. Open `tasks.sh`. It has 10 functions, `task1` ... `task10`. Each has a description.
2. Replace the `:` line of a function with your `docker` commands.
3. Run the checker:

```bash
./check.sh        # all 10 tasks
./check.sh 5      # only task 5
```

The checker runs **your commands**, and then looks at Docker: is the container there? Is the port open? Is the volume there? You get `PASS` or `FAIL` with a hint.

It only touches things that start with `lab-` (like `lab-web`), and it removes them at the start and at the end. Your other containers are safe.

## The Tasks

| # | Topic | You learn |
|---|---|---|
| 1 | Run a container | `docker run`, `-d`, `--name`, `-p` |
| 2 | Logs | `docker logs` |
| 3 | Run a command inside | `docker exec` |
| 4 | A one-time container | `--rm`, `-e`, and quotes in the shell |
| 5 | A volume | `-v name:/folder`, data that survives |
| 6 | A bind mount | `-v /my/folder:/folder:ro`, a folder of your computer |
| 7 | A network | `docker network create`, containers find each other by **name** |
| 8 | Inspect | `docker inspect -f '...'` |
| 9 | Limits | `--memory`, `--cpus` |
| 10 | Clean up | `docker rm -f`, `docker volume rm`, `docker network rm` |

## Cheat Sheet

```text
docker run [options] IMAGE [command]     create and start a container
    -d                run in the background (detached)
    --name NAME       give it a name
    -p HOST:CONTAINER publish a port
    -e KEY=VALUE      an environment variable
    -v SOURCE:PATH    a volume or a folder. Add :ro for read-only
    --rm              remove the container when it stops
    --network NAME    put it on a network

docker ps             running containers          (docker ps -a  also the stopped ones)
docker logs NAME      what the container printed
docker exec NAME cmd  run a command inside a running container
docker inspect NAME   all the details, as JSON
docker stop NAME / docker rm NAME / docker rm -f NAME
docker volume ls / create / rm        docker network ls / create / rm
```

Not sure about a command? `docker run --help` and `docker <command> --help` explain every flag.

## Port Mapping, In One Picture

```text
your computer                  the container
  http://localhost:8081  ───►  port 80   (nginx listens here)
              -p 8081:80
              host : container
```

The container has its **own** network. Without `-p`, nobody outside can reach it.

## Common Mistakes

| Problem | Reason |
|---|---|
| `docker run` works, but the page does not open | You forgot `-p`, or you swapped the numbers. It is `HOST:CONTAINER`. |
| The command never ends | `docker logs -f` follows the logs forever. Remove `-f`. |
| `echo $GREETING` prints an empty line | Your **computer** replaced `$GREETING` before Docker started. Use single quotes: `sh -c 'echo $GREETING'`. |
| "container name is already in use" | An old container has that name. `docker rm -f NAME` first. |
| `docker exec -it` fails in the checker | There is no keyboard. Use `docker exec NAME cmd` without `-it`. |
| The bind mount is empty | The path must be **absolute**. Use `"$(pwd)/site"`. |
| The network cannot be removed | A container is still on it. Remove the containers first. |

## Rules

- Write only `docker` commands in `tasks.sh`. Do not change `check.sh`.
- Use the exact names of the tasks (`lab-web`, `lab-net` ...).
