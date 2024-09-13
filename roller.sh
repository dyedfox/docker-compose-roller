#!/bin/bash

declare -A SERVICES
declare -A ENV_VARS
# my_dict["key1"]="value1"
# ${my_dict["age"]} = ${SERVICES[$SERVICE]}

if [[ -f ".roller_env" ]]; then
    source .roller_env
else
    echo "File .roller_env does not exist!"
    exit 1
fi

ACTION=$1
SERVICE=$2
DOCKERFILE=${DOCKERFILE:-"Dockerfile"}


# Trim the trailing space
env_assignments=$(echo "$env_assignments" | sed 's/ $//')

# Build new image
build() {
    if [[ -n $(docker images -q "${SERVICES[$SERVICE]}:latest") ]]; then
        docker tag "${SERVICES[$SERVICE]}:latest" "${SERVICES[$SERVICE]}:prev" # Tag current image as previous
    fi
        docker build -f "$DOCKERFILE" -t "${SERVICES[$SERVICE]}" . # Build new image, it becomes latest
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
     #   ROLL_IMAGE="${SERVICES[$SERVICE]}:latest" docker rollout "$SERVICE"
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

        # ROLL_IMAGE="${SERVICES[$SERVICE]}:prev" docker rollout "$SERVICE"
        command="$env_assignments docker rollout $SERVICE"
        eval "$command"

    else
        echo "No latest image available for rollout!"
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

        # ROLL_IMAGE="${SERVICES[$SERVICE]}:prev" docker rollout "$SERVICE"
        command="$env_assignments docker rollout $SERVICE"
        eval "$command"
        
    else
        echo "No previous image available for rollback!"
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
        
        #ROLL_IMAGE="${SERVICES[$SERVICE]}:latest" docker compose down -v || ROLL_IMAGE="${SERVICES[$SERVICE]}:prev" docker compose down -v
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
    echo "  build     - Build a Docker image"
    echo "  up        - Build (if necessary) and start containers"
    echo "  rollout   - Update a service with the new image"
    echo "  rollback  - Rollback a service to the previous image"
    echo "  down      - Stop and remove containers, networks, and volumes"
}

main() {
    echo "Running with the following parameters:"
    cat .roller_env
    echo -e "\n"
    case "$ACTION" in
        help)
            usage
            exit 0
            ;;
        build)
            if [[ -z "${SERVICES[$SERVICE]}" ]]; then
                echo -e "Error: IMAGE is required for build action\n"
                usage
                exit 1
            fi
            build
            ;;
        up)
            # if [[ -z "${SERVICES[$SERVICE]}" ]]; then
            #     echo -e "Error: IMAGE is required for up action\n"
            #     usage
            #     exit 1
            # fi
            up
            ;;
        rollout)
            if [[ -z "$2" ]]; then
                echo -e "Error: SERVICE is required for rollout action\n"
                usage
                exit 1
            fi
            rollout
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
            # if [[ -z "${SERVICES[$SERVICE]}" ]]; then
            #     echo -e "Error: IMAGE is required for down action\n"
            #     usage
            #     exit 1
            # fi
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