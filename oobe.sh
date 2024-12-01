#!/bin/bash

set -ue

DEFAULT_UID='1000'

# We know the user clab exists from Dockerfile with UID 1000
if getent passwd "$DEFAULT_UID" > /dev/null ; then
    containerlab version
    echo -e '\n'
    echo " Welcome to Containerlab's WSL distribution."
    exit 0
fi

# This part will (should) never be reached since clab user exists,
# but keeping it as a fallback
echo 'No user account detected, Something may be wrong with your installation. Create an issue at <githubIssueLink>'
exit 1