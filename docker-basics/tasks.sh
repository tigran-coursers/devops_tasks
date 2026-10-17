#!/usr/bin/env bash
# DOCKER BASICS - YOUR ANSWERS
#
# Write the docker commands inside the 10 functions below. Replace the ":" line (it does nothing).
# Then run  ./check.sh  to see which tasks are done.
#
# Rules:
#   - Write only docker commands. One function = one task. You can use several lines.
#   - Do NOT use  -it  (there is no keyboard in the checker). Use  docker exec ...  and  docker run --rm ...  without it.
#   - Use exactly the names that are written in the task (lab-web, lab-net ...).
#   - The tasks run in this order, and some tasks use what an earlier task created.
#   - All the commands run in THIS folder (devops_tasks/docker-basics).
#
# Images that you use: nginx:alpine (a small web server) and alpine (a tiny Linux).
#
# Useful: docker run, docker ps, docker logs, docker exec, docker inspect, docker volume, docker network, docker rm
#         (and "docker run --help", "docker <command> --help" when you are not sure)

# ---------------------------------------------------------------------------------------------
task1() {
    # TASK 1 - RUN A CONTAINER
    # Start a web server in the BACKGROUND:
    #   - image:           nginx:alpine
    #   - container name:  lab-web
    #   - port:            the port 80 inside the container must be reachable on port 8081 of your computer
    # Then http://localhost:8081 shows the "Welcome to nginx!" page.
    # (flags to look at: -d  --name  -p host:container)
    :
}

# ---------------------------------------------------------------------------------------------
task2() {
    # TASK 2 - LOGS
    # Print the logs of the container lab-web.
    # (The checker opens the page first, so the log has a line  GET / HTTP/1.1 ... )
    :
}

# ---------------------------------------------------------------------------------------------
task3() {
    # TASK 3 - RUN A COMMAND INSIDE A RUNNING CONTAINER
    # In the running container lab-web:
    #   1. write the text  hello  into the file /tmp/note.txt
    #   2. print the content of that file  (it must show: hello)
    # Tip: the container has a shell:  sh -c '...'   (put your commands inside the quotes)
    # (command to look at: docker exec)
    :
}

# ---------------------------------------------------------------------------------------------
task4() {
    # TASK 4 - A CONTAINER THAT IS GONE WHEN IT IS DONE
    # Run a ONE-TIME container from the image  alpine :
    #   - give it the environment variable  GREETING=Salut
    #   - it prints the value of GREETING  (it must show: Salut)
    #   - when it ends, the container is REMOVED automatically (no stopped container is left)
    # Careful with the quotes: if you write  echo $GREETING  in double quotes or without quotes,
    # YOUR computer replaces $GREETING before docker starts. Use single quotes:  sh -c 'echo $GREETING'
    # (flags to look at: --rm  -e)
    :
}

# ---------------------------------------------------------------------------------------------
task5() {
    # TASK 5 - A VOLUME: DATA THAT SURVIVES THE CONTAINER
    # A container forgets its files when it is removed. A VOLUME keeps them.
    #   1. Run a one-time alpine container that mounts the volume  lab-notes  on the folder /data
    #      and writes the text  saved  into /data/note.txt
    #   2. Run ANOTHER one-time alpine container that mounts the same volume
    #      and prints /data/note.txt  (it must show: saved)
    # Docker creates the volume for you the first time you use its name.
    # (flag to look at: -v name:/folder)
    :
}

# ---------------------------------------------------------------------------------------------
task6() {
    # TASK 6 - SHOW A FOLDER OF YOUR COMPUTER (BIND MOUNT)
    # There is a folder  site/  here, with an index.html.
    # Run nginx:alpine so that it shows YOUR page:
    #   - container name:  lab-site
    #   - host port 8082 -> container port 80, in the background
    #   - the folder  site/  of your computer is mounted on  /usr/share/nginx/html  in the container
    #   - READ-ONLY: the container must not be able to change your files (add :ro)
    # Then http://localhost:8082 shows "My Docker site".
    # Tip: a bind mount needs the FULL path of the folder. Use  "$(pwd)/site"
    :
}

# ---------------------------------------------------------------------------------------------
task7() {
    # TASK 7 - CONTAINERS TALK TO EACH OTHER (NETWORKS)
    #   1. Create a network named  lab-net
    #   2. Start nginx:alpine in the background, named  lab-web2, on the network lab-net.
    #      Do NOT publish a port (no -p). It is only for other containers.
    #   3. Run a one-time alpine container on the same network that downloads the page of lab-web2
    #      and prints it:    wget -qO- http://lab-web2
    #      (it must show the "Welcome to nginx!" page.  Look: you use the NAME of the container as the address!)
    # (commands to look at: docker network create, --network)
    :
}

# ---------------------------------------------------------------------------------------------
task8() {
    # TASK 8 - LOOK INSIDE A CONTAINER (INSPECT)
    # Print ONLY the name of the image of the container lab-web. The output must be exactly:
    #   nginx:alpine
    # Tip: docker inspect shows a lot of JSON. Use --format (or -f) with a Go template to pick one field:
    #   docker inspect -f '{{.Config.Image}}' <name>
    # Find the right field in the full output of  docker inspect lab-web .
    :
}

# ---------------------------------------------------------------------------------------------
task9() {
    # TASK 9 - LIMIT THE RESOURCES
    # A container can eat all the memory of a computer. Limit it.
    # Start a container in the background:
    #   - name:    lab-limited
    #   - image:   alpine
    #   - command: sleep 300       (it just waits)
    #   - memory limit: 64 megabytes
    #   - CPU limit: half of one CPU (0.5)
    # (flags to look at: --memory  --cpus)
    :
}

# ---------------------------------------------------------------------------------------------
task10() {
    # TASK 10 - CLEAN UP
    # Remove everything that you created in the tasks 1-9:
    #   - the containers   lab-web  lab-web2  lab-site  lab-limited   (some of them are still running!)
    #   - the volume       lab-notes
    #   - the network      lab-net
    # (commands to look at: docker rm -f, docker volume rm, docker network rm)
    :
}
