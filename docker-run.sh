#! /usr/bin/env bash

## version to check compatibility
DOCKER_RUN_VERSION=1

# Variables
DOCKER_OPTIONS_FILE='docker_options.sh'
DOCKER_OPTIONS_TEMPLATE_FILE='docker_options.sh.template'

## Download latest template file
download_f_template () {
    # Check if template is already downloaded
    if [ -f "$DOCKER_OPTIONS_TEMPLATE_FILE" ]
    then
        printf 'The file %s is already in this directory.\n' "$DOCKER_OPTIONS_TEMPLATE_FILE"
    else
        wget -q "https://raw.githubusercontent.com/yseop/docker-helper/master/${DOCKER_OPTIONS_TEMPLATE_FILE}"
        printf 'The file %s is downloaded in this directory.\n' "$DOCKER_OPTIONS_TEMPLATE_FILE"
    fi

    ## Instructions
    printf 'Please modify variables by following this guide https://github.com/yseop/docker-helper/\n'
    exit 1
}

# Check docker_options.sh 
if [ -f "$DOCKER_OPTIONS_FILE" ]
then
    source "$DOCKER_OPTIONS_FILE"

    ## Check compatibility
    if [ "$DOCKER_OPTIONS_VERSION" != "$DOCKER_RUN_VERSION" ]
    then
        ## Download latest version of docker options file
        printf 'Your %s is out of date. The latest version is downloaded.\n' "$DOCKER_OPTIONS_FILE"
        download_f_template
    fi
else
    download_f_template
fi

# Image
IMAGE=${REPOSITORY:?}/${PROJECT:?}:${TAG:?}

# “docker run” arguments.
unset -v DOCKER_RUN_ARGS
DOCKER_RUN_ARGS=(
    --rm
    --name "$PROJECT"
    -p "$PORT":"$PORT"
    --tmpfs /tmp
    "${DOCKER_CUSTOM[@]}"
    "$IMAGE"
)

# === Functions ===

dock_f_help () {
    cat << _HELP_

  Target: $IMAGE

  Usage :

    help        See possible arguments.
    build       Build docker image.
    clean       Clean docker image.
    deps        Pull latest version of FROM dockerfile.
    history     Print docker layers.
    push        Push docker image to registry (require rights).
    run         Run docker image.
    start       Run the “deps”, “build” and “run” commands.
    publish     Run the “deps”, “build”, “push”, and “clean” commands.

  Exits with the status of the last command, and 2 if
  an invalid command name was given.

_HELP_
}

# Docker dependencies
dock_f_deps () {
    local from
    
    if [ ! -f Dockerfile ] || [ ! -r Dockerfile ]
    then
        printf '%s: %s\n' "$(basename "$0")" 'Error: Could not find or read Dockerfile.' >&2
        return 1
    fi
    
    from=$(
        sed -n 's/^ *FROM *//p' Dockerfile | head -1
    )
    docker pull "${from:?Could not get “FROM” from Dockerfile.}"
}

dock_f_build () {
    docker build -t "$IMAGE" .
}
dock_f_history () {
    docker history "$IMAGE"
}
dock_f_run () {
    docker run "${DOCKER_RUN_ARGS[@]}"
}
dock_f_clean () {
    docker rmi "$IMAGE"
}
dock_f_push () {
    docker push "$IMAGE"
}

dock_f_start () {
    dock_f_deps &&
    dock_f_build &&
    dock_f_run
}

dock_f_publish () {
    dock_f_deps &&
    dock_f_build &&
    dock_f_push &&
    dock_f_clean
}

# === Main code ===

if [ $# -eq 0 ]
then
    printf '%s: %s\n' "$(basename "$0")" 'No arguments were given.' >&2
    dock_f_help    
    exit 1
else
    for command in "$@"
    do
        if [ "$(type -t dock_f_"$command")" = 'function' ]
        then
            dock_f_"$command" || exit 
        else
            printf '%s: %s\n' "$(basename "$0")" "Error: Command “${command}” not found." >&2
            exit 2
         fi
    done
fi
