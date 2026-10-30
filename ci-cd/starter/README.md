# cicd-demo - your pipeline repository

This is the repository that your **CI/CD pipeline** builds, tests and packages. The step-by-step guide is in the module `ci-cd` of `devops_tasks` (the `README.md` next to this folder).

```text
.github/workflows/ci.yml    <- YOUR TASK: write the pipeline here
src/                        the application and its tests (do not change)
pom.xml                     the Maven build (do not change)
Dockerfile                  used only by the optional deploy level
check.sh                    checks your pipeline file
```

The commands of the pipeline:

```bash
mvn -B compile                  # build
mvn -B test                     # test
mvn -B package -DskipTests      # package -> target/cicd-demo.jar
```

Check your pipeline file:

```bash
./check.sh
```

Then push to `main` and open the **Actions** tab of your GitHub repository.
