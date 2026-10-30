# GitHub Pages Release - Step By Step Guide

## The Idea

You made a website. How does the **world** see it? And when you change it, how do you do it **safely**, so you can always say "this is version 1.2.0", and go back if something breaks?

In this module you take a ready website, put it on the internet **for free**, and then **release** it step by step, like a real team does.

```text
 your code            GitHub                      the world
 (HTML, CSS, JS) ──►  repository  ──► Pages ──►  https://<you>.github.io/<repo>/
                          │
                          └──►  tags + releases:  v1.0.0   v1.1.0   v1.2.0 ...   (the history of your versions)
```

A **static site** is a site made of only files: HTML, CSS and JavaScript. There is **no server code** and **no database**. That is why GitHub can host it for free: it only has to hand out your files.

| Word | Meaning | Real life |
|---|---|---|
| **GitHub Pages** | A free service of GitHub that shows your static site at a public address. | A free shop window. |
| **Commit** | A saved change in git. | A page of a diary. |
| **Tag** | A **name** on one exact commit: `v1.1.0`. It never moves. | A bookmark. |
| **Release** | A tag **plus** release notes (and maybe files) on GitHub. | An edition of a book, with a list of what is new. |
| **Version** | `MAJOR.MINOR.PATCH`, for example `1.2.3`. | The edition number. |
| **Changelog** | The list of what changed in each version. | The "what is new" page. |
| **Rollback** | Going back to a working state after a bad release. | Taking a bad book edition back. |
| **Pipeline** | A robot that does a job for you on GitHub (Actions). | A machine on a conveyor belt. |

### How to choose the next version number (Semantic Versioning)

| Number | Change it when | Example |
|---|---|---|
| **PATCH** (1.2.**3**) | you fix a bug, nothing new | `1.2.3` → `1.2.4` |
| **MINOR** (1.**2**.3) | you add something new that still works as before | `1.2.4` → `1.3.0` |
| **MAJOR** (**1**.2.3) | you change something that breaks the old way | `1.3.0` → `2.0.0` |

When you raise a number, the numbers on its right go back to `0`.

## What You Need

- A **GitHub account** (free), and `git` installed
- A terminal (`bash` or `zsh`), `curl`
- **No Docker, no Java, no Node.** Only files.

> **Your repository must be PUBLIC.** On the free plan, GitHub Pages works only for public repositories. Do not put anything secret in it.

## The Site

The folder `site/` has a small ready website. You only change tiny things in it:

```text
site/
├── index.html        the page
├── style.css         the colors
├── app.js            reads version.json and changelog.json, and shows them
├── version.json      {"version": "1.0.0"}     <- the version of your site
└── changelog.json    the list of releases     <- every release adds a line here
```

The page shows `Current version: v1.0.0` and the changelog. **When you release, you change `version.json` and `changelog.json`**, and the page shows the new version. That is how you can see, with your own eyes, which release is online.

The folder `workflows/` has two pipeline files with `TODO`s. You use them in levels 3 and 5.

> **Use your own website instead?** You can. Any static site works (plain HTML, or the `dist/` or `build/` folder of a React/Vue/Vite app). Add a small `version.json` like `{"version": "1.0.0"}` at the root of the published files, because `./check.sh` reads it. Two traps: use **relative** paths (`style.css`, not `/style.css`) because the site lives in `/<repo>/`, and for Vite set `base: '/<repo>/'`.

## How Your Work Is Checked

```bash
./check.sh <github-user> <repo-name> <folder-of-your-repo>
# example:
./check.sh tigran my-site ~/my-site
```

It looks at three things: **your live site**, **GitHub** (your tags, releases and pipeline runs, which are public), and **your computer** (the pipeline files and your git history). It tells you what is done and what to do next.

- **Be patient.** After a push, GitHub needs **1 or 2 minutes** to update the site. If a check fails right after a push, wait a little and run it again.
- GitHub lets anyone read public data **60 times per hour**. A full check uses about 10. If you see strange failures after many runs, wait an hour.

## Step 0 - Make Your Repository

1. On GitHub click **New repository**. Name it `my-site`. Choose **Public**. Do **not** add a README. Click **Create**.
2. Copy the **content** of the folder `site/` into a new folder outside `devops_tasks`. Note the **dot** after `site/`: it copies everything, also hidden files.

```bash
mkdir ~/my-site
cp -R site/. ~/my-site/
cd ~/my-site
```

3. Make it a git repository, and push it:

```bash
git init -b main
git add .
git commit -m "first commit: the site, version 1.0.0"
git remote add origin https://github.com/<your-name>/my-site.git
git push -u origin main
```

Reload your repository page on GitHub: you see `index.html`, `style.css`, `app.js` ... **in the root**, not inside a folder.

---

## Level 1 - Publish The Site

Your files are on GitHub, but nobody can see the **website** yet. Switch Pages on:

1. In your repository click **Settings** (the tab with the gear).
2. In the left menu click **Pages**.
3. Under **Build and deployment** → **Source**, choose **Deploy from a branch**.
4. Under **Branch**, choose `main` and the folder `/ (root)`. Click **Save**.
5. Wait one or two minutes. Reload the Pages settings: a green box says **"Your site is live at ..."**.
6. Open the address: `https://<your-name>.github.io/my-site/`

You see `My Release Journey` with `Current version: v1.0.0`. **Your site is on the internet.** Anybody can open this address.

```bash
./check.sh <your-name> my-site ~/my-site
```

**Run this check now, before you start level 2.** The checker remembers the version that it saw first (`1.0.0`), and level 2 compares your new version with it.

## Level 2 - Change The Site, Publish Again

A release is a **change that people can see**. Make your first one:

1. Open `index.html` and change a text (the `<h1>` or the subtitle).
2. Open `version.json` and raise the version. You added something new, so this is a **MINOR** change:

```json
{
  "version": "1.1.0"
}
```

3. Open `changelog.json` and add a new entry at the **end** of the list (do not forget the comma after the old entry):

```json
{
  "entries": [
    { "version": "1.0.0", "date": "2026-01-01", "notes": "First version of the site." },
    { "version": "1.1.0", "date": "2026-02-01", "notes": "New title and a changelog." }
  ]
}
```

4. Commit and push:

```bash
git add .
git commit -m "Release 1.1.0: new title"
git push
```

5. Wait a minute. Open the site again (press **Ctrl+Shift+R** or **Cmd+Shift+R** to skip the browser cache). It shows `v1.1.0` and your two changelog lines.

## Level 3 - Deploy With A Pipeline

Until now GitHub published your site by itself. Real teams write the deployment as a **pipeline**, because then it is visible, repeatable, and they can add checks before it.

1. **Switch the source.** Settings → Pages → **Source: GitHub Actions**.
2. Copy the file `workflows/pages.yml` of this module into your repository:

```bash
mkdir -p ~/my-site/.github/workflows
cp workflows/pages.yml ~/my-site/.github/workflows/pages.yml
```

3. Open it and **write the pipeline** (remove the `# `, fill the `_____`). It has 4 TODOs.
4. Check the file before you push: `./check.sh ...` (the online check will fail until the pipeline ran).
5. Push:

```bash
cd ~/my-site
git add .
git commit -m "Deploy the site with a GitHub Actions pipeline"
git push
```

6. Open the **Actions** tab. You see a run named **Deploy to GitHub Pages**, with a yellow circle, then a green check. Click it, click the job `deploy`: you see every step and its log. At the end, the **address of the site** is shown.

From now on, every push to `main` **deploys** the site by this pipeline. (You can also click **Run workflow** in the Actions tab, because of `workflow_dispatch`.)

**What each step does:**

| Step | Job |
|---|---|
| `actions/checkout` | gets your files onto the pipeline's machine |
| `actions/configure-pages` | prepares the Pages settings |
| `actions/upload-pages-artifact` | packs the folder to publish |
| `actions/deploy-pages` | publishes the package |

## Level 4 - A Version Tag And A Release (By Hand)

Your site shows `v1.1.0`. Now make `v1.1.0` a **release**: a permanent, named version that you can always come back to.

**The rule: first change the version in the files, push it, and only then tag.** A tag marks the exact code that you released. If the tag points to code that still says `1.0.0`, the name lies.

1. Check that your last commit (the one with `1.1.0` in `version.json`) is pushed.
2. Make the tag and push it:

```bash
git tag -a v1.1.0 -m "Version 1.1.0"
git push origin v1.1.0
```

3. On GitHub, open **Releases** (right side of the main page of the repository) → **Draft a new release**.
4. **Choose a tag:** `v1.1.0`. **Release title:** `v1.1.0`.
5. Click **Generate release notes**: GitHub writes a list of the changes. Add a sentence in your own words.
6. Click **Publish release**. (Not "Save draft": a draft is not public.)

Now look at the page of the release: you see the notes, and GitHub offers to download the code **exactly as it was** at `v1.1.0`. In a year, you can still get it.

## Level 5 - Automatic Releases

Making a release by hand with the mouse is slow, and people forget steps. Let a pipeline do it: you **push a tag**, and the pipeline creates the release, **with a file** (`site.zip`) that people can download.

1. Copy the file `workflows/release.yml` into your repository, and write it (3 TODOs):

```bash
cp workflows/release.yml ~/my-site/.github/workflows/release.yml
```

2. Commit and push it to `main`.
3. Now make **release 1.2.0**. Raise the version in `version.json` to `1.2.0`, add a line to `changelog.json`, commit, push. Wait for the Pages pipeline to finish.
4. **Tag and push the tag.** Do not create the release by hand this time:

```bash
git tag -a v1.2.0 -m "Version 1.2.0"
git push origin v1.2.0
```

5. Open the **Actions** tab: a new run named **Release** starts. When it is green, open **Releases**: `v1.2.0` is there. Look at the author: it is **github-actions**. At the bottom, in **Assets**, there is `site.zip`: download it and look inside.

This is the real flow of many teams: **commit → tag → the pipeline makes the release**.

## Level 6 - Something Went Wrong: Roll Back

Every team ships a bad release one day. What matters is how **fast and calm** you fix it. Let us practice. You will **break the site on purpose**.

**1. Make release 1.3.0, with a bug.**

- In `index.html` change the script line from `<script src="app.js">` to `<script src="/app.js">` (add a `/`). It looks like nothing, but now the browser looks for `https://<you>.github.io/app.js` and finds nothing: **the site cannot load its data** any more.
- Raise `version.json` to `1.3.0`, add a changelog line ("Banner on the home page"), commit, push.
- Tag and push the tag: `git tag -a v1.3.0 -m "Version 1.3.0"` and `git push origin v1.3.0`.
- When the pipelines are green, open your site. The version says `loading...` and the changelog is empty. **This is the incident.**

**2. Roll back (undo the bad change).** Do not edit by hand in a panic. Use `git revert`. It makes a **new commit** that undoes an old one, and keeps the history honest:

```bash
git log --oneline                 # find the commit "Banner..." that you pushed in step 1
git revert <that-commit-id>       # git opens an editor with the message "Revert ..."; save and close it
git push
```

When the Pages pipeline is green, the site works again.

**3. Release the fix as a NEW version.** Never delete a release and never move a tag: people may already use `v1.3.0`. You publish a **higher** version, `v1.3.1` (a PATCH, because it is a fix):

- Set `version.json` to `1.3.1`, add a changelog line ("Fix: the site did not load its data"), commit, push.
- Tag and push: `git tag -a v1.3.1 -m "Version 1.3.1"` and `git push origin v1.3.1`.
- The pipeline creates the release `v1.3.1`.

**4. Warn the people.** Open the release page of `v1.3.0`, click **Edit**, and write at the top: "Broken. Use v1.3.1." (Tick **Set as a pre-release** if you like.)

You just did a real **incident response**: find, undo, fix with a new version, communicate.

## Level 7 (BONUS) - Your Own Domain

`<you>.github.io/my-site` is already a public address. If you have your own domain (for example `www.mysite.com`), Pages can use it.

> A domain is not free (usually about 10 euro a year). This level is optional.

1. Settings → Pages → **Custom domain**: type your domain, **Save**.
2. At the company where you bought the domain, add a DNS record: for a name like `www.mysite.com`, a **CNAME** record that points to `<you>.github.io`. (For a bare domain like `mysite.com`, GitHub's current documentation lists the IP addresses for the `A` records.)
3. Add a file named `CNAME` to the root of your repository with **one line**: your domain. Commit and push.
4. Wait (DNS can take from minutes to hours). Then tick **Enforce HTTPS** in the Pages settings.

Check it: `CUSTOM_DOMAIN=www.mysite.com ./check.sh <your-name> my-site ~/my-site`

---

## Common Mistakes

| Problem | Reason |
|---|---|
| The address shows **404** | Pages is not switched on, the repository is private, the branch/folder is wrong, or it is not ready yet (wait 1-2 minutes). Check the exact address: it is case sensitive. |
| The page is **white**, or has no colors | A path starts with `/` (`/style.css`). It must be relative: `style.css`. |
| The page shows **loading...** forever | `version.json` or `changelog.json` is missing, has a typo (a missing comma), or the script path is wrong. Open the browser console (F12). |
| My change is not on the site | You did not push, the pipeline is still running (Actions tab), or your browser shows an old copy: press **Ctrl+Shift+R**. |
| Level 2 fails: "the version is still 1.0.0" | You changed `version.json` but did not push, or the deployment is not finished. |
| Level 3: the pipeline fails with "Get Pages site failed" | In Settings → Pages the Source is not **GitHub Actions**. |
| Level 3: the deploy job waits and waits | The first run of the environment `github-pages` may need a minute. If it says "waiting for approval", open the run and approve. |
| Level 4: "the tag points to code with version 1.0.0" | You made the tag **before** you changed `version.json`. Delete the tag (`git tag -d v1.1.0` and `git push origin :refs/tags/v1.1.0`) and make it again after the bump. |
| Level 5: no release appears | The pipeline `release.yml` is not on `main` yet when you push the tag, or it has no `contents: write`. Look at the **Actions** tab. |
| Level 5: "Resource not accessible by integration" | The pipeline has no `permissions: contents: write`. |
| Level 6: the check says "no revert commit" | You fixed it by hand. Use `git revert`, so the history shows it. |
| `git push origin v1.1.0` says "already exists" | The tag exists already. Raise the version and make a new tag. |

## Rules

- Your repository must be **public**, and must not contain secrets (passwords, keys).
- A tag is **never** moved or deleted after it is public. A fix is a **new, higher version**.
- The version in `version.json` must always say what is online.
- `./check.sh` shows what GitHub shows. The real proof is **your site, open in a browser**, at a public address.
