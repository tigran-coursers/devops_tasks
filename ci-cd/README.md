# CI/CD - Step By Step Guide

## The Idea

Imagine a factory with a **conveyor belt**. A worker puts a new part on the belt. Machines check it, test it, pack it, and at the end the box is ready to ship. Nobody has to remember to do each step, and a bad part is stopped **before** it reaches the box.

A **CI/CD pipeline** is the same for software. Every time somebody pushes code, a robot does the work for you:

```text
 you push        ┌─────────┐    ┌─────────┐    ┌───────────┐    ┌──────────┐
 to "main" ────► │  BUILD  │──► │  TEST   │──► │  PACKAGE  │──► │  DEPLOY  │
                 │ compile │    │ run the │    │ make the  │    │ send it  │
                 │ the code│    │ tests   │    │ jar file  │    │ to a     │
                 └─────────┘    └─────────┘    └───────────┘    │ server   │
                    stop here if one stage fails: red X         └──────────┘
```

| Word | Meaning |
|---|---|
| **CI** (Continuous Integration) | Every push is **built and tested** automatically, so a broken change is found in minutes. |
| **CD** (Continuous Delivery / Deployment) | The result is **packaged** and **sent to a server** automatically. |
| **Pipeline** | The whole chain of steps. |
| **Stage** (a *job* in GitHub Actions) | One step of the chain: build, test, package ... |
| **Trigger** | What starts the pipeline. Here: a push to the branch `main`. |
| **Runner** | The machine (a computer in the cloud) that runs your job. |
| **Artifact** | A file that a job **keeps** for you: the jar, the test reports. |
| **Secret** | A password or a key that the pipeline needs, stored safely **outside** your code. |

## Which Tool? GitHub Actions, GitLab CI Or Jenkins?

| | **GitHub Actions** | GitLab CI/CD | Jenkins |
|---|---|---|---|
| Where it runs | GitHub's cloud. **Nothing to install.** | GitLab's cloud (or your own server) | **Your own server.** You install and look after it. |
| Pipeline file | `.github/workflows/*.yml` | `.gitlab-ci.yml` | `Jenkinsfile` |
| Cost | Free for public repositories, and a monthly allowance for private ones | Free monthly allowance | The software is free. The **server** is yours to pay for. |
| Setup time | **0 minutes**: it is already in your GitHub repository | A GitLab account and project | Hours (install, plugins, a public address for webhooks) |
| Best for | Projects on GitHub. **Learning.** | Projects on GitLab | Big companies with their own servers |

**This module uses GitHub Actions**, because your code is already on GitHub, and there is nothing to install. The **ideas are the same in all three tools**: a trigger, stages, commands, artifacts, secrets. When you know one, the others take an afternoon. At the end of this guide you see the same pipeline written for GitLab CI and for Jenkins.

## What You Need

- A **GitHub account** (free) and `git`
- JDK 21 and Maven (for the checks on your own computer)
- Nothing else. **No Docker is needed** for this module.

## The Application

`starter/` is a tiny Java web application, with tests. It is only here to give the pipeline something to build, test and package:

```text
GET /health       OK
GET /greet?name=Anna     Hello, Anna!
GET /version      version 1.0.0 (build 42)     <- the number of the pipeline run that built it
```

The three commands of the pipeline already work on your computer:

```bash
mvn -B compile                  # build
mvn -B test                     # test (10 tests)
mvn -B package -DskipTests      # package: target/cicd-demo.jar
```

**Your job:** write the file `.github/workflows/ci.yml` so that GitHub runs these three commands, in this order, every time somebody pushes to `main`.

## How It Works

A pipeline belongs to a **repository**, and it must be in the **root** of the repository. So you work in your **own new repository**:

**Step 1 - Make your repository.** On GitHub, click **New repository**. Name it `cicd-demo`. Keep it **empty** (no README, no `.gitignore`).

**Step 2 - Copy the starter.** Copy the **folder** `starter` to a place **outside** `devops_tasks` (a repository inside a repository is confusing), and go into it:

```bash
cp -R starter ~/cicd-demo
cd ~/cicd-demo
```

**Step 3 - Push it.**

```bash
git init -b main
git add .
git commit -m "first commit"
git remote add origin https://github.com/<your-name>/cicd-demo.git
git push -u origin main
```

Open your repository on GitHub, and click the **Actions** tab. Nothing runs: your pipeline file is empty. Now you write it.

**Step 4 - Write the pipeline, level by level**, in `.github/workflows/ci.yml`.

**Step 5 - Check your file before you push:**

```bash
./check.sh
```

It does two things: it runs the three Maven commands on your computer (if they fail here, they fail in the pipeline), and it **reads your pipeline file** and checks it, level by level. It cannot *run* the pipeline: only GitHub can do that.

**Step 6 - Push, and watch.**

```bash
git add .github/workflows/ci.yml
git commit -m "add the pipeline"
git push
```

Go to the **Actions** tab: your run appears. Click it. You see your **jobs** as boxes, joined by arrows. Click a job to see its log, line by line. A green check means success, a red cross means a stage failed.

---

## Level 1 - The Trigger

The trigger says **when** the pipeline starts. It is the `on:` part:

```yaml
name: CI/CD

on:
  push:
    branches: [ _____ ]      # only the branch main
```

Look at the indentation. In YAML the **spaces** are the structure: 2 spaces for each level, and **never a tab**.

## Level 2 - The Three Stages

A stage is a **job**. Each job runs on its own **fresh machine** (a runner). That is the most important thing to understand: the machine of `test` knows **nothing** about the machine of `build`. So every job must start by getting the code and Java:

```yaml
jobs:
  build:
    runs-on: _____                  # a Linux machine: ubuntu-latest
    steps:
      - uses: actions/checkout@v4   # download the code of the repository
      - uses: actions/setup-java@v4 # install Java
        with:
          distribution: temurin
          java-version: '_____'     # 21
```

Write the **same** start for `test` and `package` (copy and paste). `uses:` runs a ready-made **action** that somebody else wrote. `run:` (next level) runs a **command**.

## Level 3 - The Commands And The Order

Add a `run` step to each job, and tell the jobs to wait for each other:

```yaml
  build:
    steps:
      ...
      - run: mvn -B _____           # compile

  test:
    needs: _____                    # start only after build succeeded
    steps:
      ...
      - run: mvn -B test

  package:
    needs: _____                    # start only after test succeeded
    steps:
      ...
      - run: mvn -B package -DskipTests
```

- **`needs:`** makes the order. Without it the three jobs start **at the same time**. With it, a failed stage **stops** the chain: a broken build is never tested, and a failing test is never packaged. That is the whole point of a pipeline.
- `-B` ("batch mode") makes Maven print clean logs. `-DskipTests` in `package` is there because the tests **already ran** in the test stage. There is no reason to run them twice.

## Level 4 - The Artifacts

When a job ends, its machine is **thrown away** with everything on it. If you want to keep a file, you must **upload** it as an **artifact**:

```yaml
  test:
    steps:
      ...
      - run: mvn -B test
      - uses: actions/upload-artifact@v4
        if: _____                   # always(): also when the tests FAIL
        with:
          name: test-reports
          path: target/surefire-reports

  package:
    steps:
      ...
      - uses: actions/upload-artifact@v4
        with:
          name: cicd-demo-jar
          path: target/_____        # the jar: cicd-demo.jar
```

**Why `if: always()`?** When a step fails, GitHub **skips the steps after it**. So if the tests fail, the upload would be skipped, and you would lose exactly the report that explains the failure.

**Try it:** after a green run, open the run page and scroll to **Artifacts**. Download `cicd-demo-jar`, unzip it, and start it:

```bash
java -jar cicd-demo.jar
# in another terminal:
curl http://localhost:8080/version
```

## Level 5 - Speed And Safety

Four things that every real pipeline has. All are small:

```yaml
name: CI/CD

on: ...

permissions:
  contents: _____                  # read: the pipeline can only READ your repository

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: _____        # true: a new push cancels the old run of the same branch

jobs:
  build:
    timeout-minutes: 10            # a stuck job must not run for hours
    steps:
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: _____             # maven: the libraries are not downloaded again every time
```

Put `timeout-minutes` and `cache: maven` in **every** job.

| Setting | Why |
|---|---|
| `cache: maven` | The first run downloads the libraries. The next ones take them from a cache: much faster. |
| `permissions: contents: read` | **Least privilege.** If somebody steals the pipeline, it can only read. |
| `timeout-minutes` | A stuck job costs money and blocks the others. |
| `concurrency` | If you push 3 times in a minute, only the last one matters. |

Also: **never write a secret in this file.** A pipeline file is part of your repository, and everybody can read it. Secrets go into **Settings → Secrets and variables → Actions**, and you use them with `${{ secrets.NAME }}`.

## Level 6 (BONUS) - Deploy To A Free Server

Packaging gives you a jar. **Deploying** puts the application on a **server**, so other people can open it in a browser. This is the "CD" of CI/CD.

### A free hosting service

The easiest free option for beginners is **[Render](https://render.com)** (a free "Web Service"). It builds the `Dockerfile` that is in `starter/` **on its own servers**, so you do not need Docker on your computer.

> **Free hosting changes often.** Free plans, limits and the need for a credit card can change at any time. Read the current rules of the service before you sign up. Other services with a free or trial plan: Fly.io, Koyeb, Railway, Google Cloud Run. Some of them ask for a card. **This level is a bonus**: if you cannot get a free server, stop after level 5 and you have a complete CI pipeline.

**What to know about the free plan of Render:** the application **goes to sleep** after about 15 minutes without visitors, and the next request takes up to a minute to wake it up. That is why the smoke test below **retries**.

### Set up Render (once)

1. Create an account on Render, and connect your GitHub account.
2. **New → Web Service**, choose your repository `cicd-demo`.
3. **Language: Docker.** **Instance type: Free.**
4. In the settings of the service set **Auto-Deploy** to **Off**. (We want the **pipeline** to decide when to deploy, after the tests passed. If Auto-Deploy is on, Render deploys every push, even a broken one.)
5. Create the service. Render builds it. When it is live, you get an address like `https://cicd-demo-abcd.onrender.com`. Open `/health` on it.
6. In the settings of the service find **Deploy Hook**: a secret URL. If somebody calls it (an HTTP `POST`), Render deploys the latest commit. **Copy it.**

### Give the pipeline the two values

In your GitHub repository: **Settings → Secrets and variables → Actions**.

- Tab **Secrets → New repository secret**: name `RENDER_DEPLOY_HOOK_URL`, value = the Deploy Hook URL. (It is a **secret** because anyone with this URL can trigger deployments.)
- Tab **Variables → New repository variable**: name `APP_URL`, value = `https://cicd-demo-abcd.onrender.com` (your address, no `/` at the end). (It is a **variable**, not a secret, because the address is public.)

### Write the deploy job

```yaml
  deploy:
    needs: package
    runs-on: ubuntu-latest
    timeout-minutes: 15
    environment: _____                 # production: GitHub lists the deployments of an environment
    steps:
      - name: Tell Render to deploy
        run: curl -fsS -X POST "${{ secrets._____ }}"      # RENDER_DEPLOY_HOOK_URL

      - name: Smoke test
        env:
          APP_URL: ${{ vars.APP_URL }}
        run: |
          for i in $(seq 1 30); do
            if curl -fsS "$APP_URL/_____"; then exit 0; fi     # the health address
            echo "not ready yet ($i/30)"
            sleep 10
          done
          exit 1
```

- **`curl -f`** makes curl **fail** when the server answers an error (404, 500). Without `-f`, curl says "success" for any answer, and your pipeline stays green when the deploy failed. **Every** curl in a pipeline needs `-f`.
- **The smoke test** does not trust the deploy: after it, it calls `/health` of the **real running application**. It tries up to 30 times, 10 seconds apart (5 minutes), because a sleeping or a new instance needs time. If it never answers, the job fails.
- A new job does not have the files of the repository. The deploy job does not need them: it only sends two HTTP requests, so it has no `checkout` and no Java.

### See it work

Change the text in `GreetingService.java` (for example `"Hello, world!"` to `"Hello, everybody!"`), commit and push. The pipeline builds, tests, packages and deploys. After a minute open `https://<your-address>/greet` in the browser: the new text is there. Then open `/version`: the **build number** is the number of your pipeline run.

---

## Experiments (do them after everything is green)

1. **Break a test.** In `GreetingServiceTest` change an expected text, push, and watch the pipeline turn **red** at the `test` stage. Look at the log, and download the `test-reports` artifact. Notice that `package` and `deploy` **did not run**. Fix the test, push: green again.
2. **Push to another branch.** `git switch -c dev`, change something, `git push -u origin dev`. The pipeline does **not** start: the trigger is only `main`.
3. **Remove `needs: test` from `package`**, and push a broken test. What happens? Now put it back.
4. **Look at the cache.** Compare the time of the first run with the second.

## The Same Pipeline In Other Tools (for comparison, not checked)

The words change, the ideas stay.

**GitLab CI** (`.gitlab-ci.yml`):

```yaml
stages: [build, test, package]

default:
  image: maven:3.9-eclipse-temurin-21

build:
  stage: build
  script: mvn -B compile
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

test:
  stage: test
  script: mvn -B test
  artifacts:
    when: always
    reports:
      junit: target/surefire-reports/*.xml
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'

package:
  stage: package
  script: mvn -B package -DskipTests -Dbuild.number=$CI_PIPELINE_IID
  artifacts:
    paths: [target/cicd-demo.jar]
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
```

**Jenkins** (`Jenkinsfile`):

```groovy
pipeline {
    agent any
    stages {
        stage('Build') {
            steps { sh 'mvn -B compile' }
        }
        stage('Test') {
            steps { sh 'mvn -B test' }
            post { always { junit 'target/surefire-reports/*.xml' } }
        }
        stage('Package') {
            steps {
                sh "mvn -B package -DskipTests -Dbuild.number=${env.BUILD_NUMBER}"
                archiveArtifacts artifacts: 'target/cicd-demo.jar'
            }
        }
    }
}
```

| Idea | GitHub Actions | GitLab CI | Jenkins |
|---|---|---|---|
| The whole file | workflow | pipeline | pipeline |
| One stage | `job` | `job` in a `stage` | `stage` |
| Order | `needs:` | the order of `stages:` | the order in `stages { }` |
| What starts it | `on:` | `rules:` | webhook or polling |
| The machine | runner (`runs-on`) | runner (`image`) | agent |
| Keep a file | `upload-artifact` | `artifacts:` | `archiveArtifacts` |
| A password | `secrets` | masked CI/CD variables | credentials |

## Common Mistakes

| Problem | Reason |
|---|---|
| The **Actions** tab is empty after a push | The file is not exactly at `.github/workflows/ci.yml` in the **root** of the repository, or you pushed another branch. |
| `mapping values are not allowed here` or `found character '\t'` | A YAML indentation problem. Use **spaces**, never tabs. |
| `test` fails with `mvn: command not found` or a Java error | The job forgot `actions/setup-java`. Every job starts on a **fresh** machine. |
| `package` fails with "no pom.xml" | The job forgot `actions/checkout`. |
| The three jobs run at the same time | `needs:` is missing. |
| The pipeline is green, but there is no jar | The upload path is wrong: `target/cicd-demo.jar`. |
| No test report after a failed test | The upload step needs `if: always()`. |
| `Context access might be invalid: RENDER_DEPLOY_HOOK_URL` | The secret does not exist, or its name has a typo (**Settings → Secrets and variables → Actions**). |
| The deploy job is green, but the site did not change | `curl` without `-f`, or Auto-Deploy is **on** in Render and the old build is live. |
| The smoke test fails once, then works | The free instance was asleep. Increase the number of tries. |

## Rules

- Write the pipeline in `.github/workflows/ci.yml`. Do not change the application code (only for the experiments).
- Never write a secret (a URL with a key, a token, a password) in the file. Use `${{ secrets.NAME }}`.
- `./check.sh` checks **what the file says**. The real proof is a **green run** on the Actions tab of your repository.
