#!/bin/bash

set -ue

DEFAULT_UID='1000'

# We know the user clab exists from Dockerfile with UID 1000
if getent passwd "$DEFAULT_UID" > /dev/null ; then
    echo 'User account clab already exists, skipping creation'
    exit 0
fi

# This part will never be reached since clab user exists,
# but keeping it as a fallback
echo 'Please create a default UNIX user account. The username does not need to match your Windows username.'
echo 'For more information visit: https://aka.ms/wslusers'
exit 1