#!/bin/sh
# Pretends to download the libraries of an application.
# It is SLOW (2 seconds), like a real "mvn dependency:go-offline" or "npm install".
# It writes a unique number into the file "deps-id", so we can see if this step was run again.
echo "installing dependencies..."
sleep 2
cat /proc/sys/kernel/random/uuid > deps-id
echo "done"
