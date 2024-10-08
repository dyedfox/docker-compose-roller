#!/bin/bash

declare -A SERVICES
declare -A ENV_VARS
declare -A DOCKERFILES

if [[ -f "roller.conf" ]]; then
    source roller.conf
else
    echo "File roller.conf does not exist!"
    exit 1
fi

ACTION=$1
SERVICE=$2

# Build new image
build() {
    if [[ -n $(docker images -q "${SERVICES[$SERVICE]}:latest") ]]; then
        docker tag "${SERVICES[$SERVICE]}:latest" "${SERVICES[$SERVICE]}:prev" # Tag current image as previous
    fi
        docker build -f "${DOCKERFILES[$SERVICE]}" -t "${SERVICES[$SERVICE]}" . # Build new image, it becomes latest
}

# Run docker compose stack with the latest images
up() {
    env_assignments=""
    for service in "${!ENV_VARS[@]}"; do
        env_var="${ENV_VARS[$service]}"
        image="${SERVICES[$service]}"
        env_assignments+="$env_var=${image}:latest "
    done
    env_assignments=$(echo "$env_assignments" | sed 's/ $//') # Trim the trailing space
    command="$env_assignments docker compose up -d"
    eval "$command"
}

# Rollout to the latest built image
rollout() {
    # build #- can be an option
    if [[ -n $(docker images -q "${SERVICES[$SERVICE]}:latest") ]]; then

        env_assignments=""
        for service in "${!ENV_VARS[@]}"; do
            env_var="${ENV_VARS[$service]}"
            image="${SERVICES[$service]}"
            if [[ $service == "$SERVICE" ]]; then
                env_assignments+="$env_var=${image}:latest "
            else
                env_assignments+="$env_var=${image} "
            fi
        done
        env_assignments=$(echo "$env_assignments" | sed 's/ $//') # Trim the trailing space

        command="$env_assignments docker rollout -f $DOCKER_COMPOSE_FILE $SERVICE"
        eval "$command"

    else
        echo "ERROR: No latest image available for rollout!"
        exit 1
    fi
}

# Rollout non-custom  built service
rollout_non_custom() {
    NON_CUSTOM_SERVICE=$1
    if [[ -n "$NON_CUSTOM_SERVICE" ]]; then
        # build #- can be an option
        env_assignments=""
        for service in "${!ENV_VARS[@]}"; do
            env_var="${ENV_VARS[$service]}"
            image="${SERVICES[$service]}"
            env_assignments+="$env_var=${image} "
        done
            env_assignments=$(echo "$env_assignments" | sed 's/ $//') # Trim the trailing space

            command="$env_assignments docker rollout -f $DOCKER_COMPOSE_FILE $NON_CUSTOM_SERVICE"
            eval "$command"
    else
        echo "ERROR: SERVICE is requires for rollout!"
        exit 1
    fi
}

# Rollback to the previous image
rollback() {
    if [[ -n $(docker images -q "${SERVICES[$SERVICE]}:prev") ]]; then
        
        env_assignments=""
        for service in "${!ENV_VARS[@]}"; do
            env_var="${ENV_VARS[$service]}"
            image="${SERVICES[$service]}"
            if [[ $service == "$SERVICE" ]]; then
                env_assignments+="$env_var=${image}:prev "
            else
                env_assignments+="$env_var=${image} "
            fi
        done
        env_assignments=$(echo "$env_assignments" | sed 's/ $//') # Trim the trailing space

        command="$env_assignments docker rollout -f $DOCKER_COMPOSE_FILE $SERVICE"
        eval "$command"
        
    else
        echo "ERROR: No previous image available for rollback!"
        exit 1
    fi
}

# Down all docker compose stack!
down() {
    echo "WARNING: This will stop and remove all containers, networks, and volumes defined in the docker-compose file."
    read -p "Are you sure you want to proceed? (y/N): " confirm
    if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
        echo "Stopping and removing containers, networks, and volumes..."          
       
        env_assignments=""
        for service in "${!ENV_VARS[@]}"; do
            env_var="${ENV_VARS[$service]}"
            image="${SERVICES[$service]}"
            env_assignments+="$env_var=${image} "
        done
        env_assignments=$(echo "$env_assignments" | sed 's/ $//') # Trim the trailing space
       
        command="$env_assignments docker compose down"
        eval "$command"

        echo "Operation completed."
    else
        echo "Operation cancelled."
    fi
}

usage() {
    echo "Usage: roller <action> [service]"
    echo "Actions:"
    echo "  build                  - Build a Docker image"
    echo "  up                     - Build (if necessary) and start containers"
    echo "  rollout                - Update a service with the new image"
    echo "  rollout --non-custom   - Rollout/rollback a non-custom service"
    echo "     (Info: Rollback for custom image is essentially the same as rollout. Please refer to the documentation)"
    echo "  rollback               - Rollback a service to the previous image"
    echo "  down                   - Stop and remove containers, networks, and volumes"
}

main() {
    echo -e "Running with the following parameters:\n"
    grep -v '^\s*#' roller.conf | grep -v '^\s*$'
    echo -e "\n"
    case "$ACTION" in
        help)
            usage
            exit 0
            ;;
        build)
            if [[ -z "$2" ]]; then
                echo -e "Error: SERVICE is required for build action\n"
                usage
                exit 1
            fi
            build
            ;;
        up)
            up
            ;;
        rollout)
            if [[ -z "$2" ]]; then
                echo -e "Error: SERVICE is required for rollout action\n"
                usage
                exit 1
            elif [[ "$2" == "--non-custom" ]]; then
                rollout_non_custom "$3"
            else
                rollout
            fi
            ;;
        rollback)
            if [[ -z "$2" ]]; then
                echo -e "Error: SERVICE is required for rollback action\n"
                usage
                exit 1
            fi
            rollback
            ;;
        down)
            down
            ;;
        *)
            echo -e "Error: Invalid action / Insufficient arguments\n"
            usage
            exit 1
            ;;
    esac
}

main "$@"