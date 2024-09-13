#!/bin/bash

if [[ -f ".roller_env" ]]; then
    source .roller_env
else
    echo "File .roller_env does not exist!"
    exit 1
fi

ACTION=$1
SERVICE=$2
DOCKERFILE=${DOCKERFILE:-"Dockerfile"}
# IMAGE_NAME=$2
# SERVICE=$3 / DOCKERFILE=${3:-"Dockerfile"}

# Build new image
build() {
    if [[ -n $(docker images -q "$IMAGE_NAME:latest") ]]; then
        docker tag "$IMAGE_NAME:latest" "$IMAGE_NAME:prev" # Tag current image as previous
    fi
        docker build -f "$DOCKERFILE" -t "$IMAGE_NAME" . # Build new image, it becomes latest
}

# Run docker compose stack. Build image if it does not exist
up() {
    DOCKERFILE=${1:-"Dockerfile"}
    if [[ -z $(docker images -q "$IMAGE_NAME:latest") ]]; then
        docker build -f "$DOCKERFILE" -t "$IMAGE_NAME" .
    fi
    ROLL_IMAGE="$IMAGE_NAME:latest" docker compose up -d
}

# Rollout to the latest built image
rollout() {
    # build #- can be an option
    if [[ -n $(docker images -q "$IMAGE_NAME:latest") ]]; then
        ROLL_IMAGE="$IMAGE_NAME:latest" docker rollout "$SERVICE"
    else
        echo "No latest image available for rollout!"
        exit 1
    fi
}

# Rollback to the previous image
rollback() {
    if [[ -n $(docker images -q "$IMAGE_NAME:prev") ]]; then
        ROLL_IMAGE="$IMAGE_NAME:prev" docker rollout "$SERVICE"
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
        ROLL_IMAGE="$IMAGE_NAME:latest" docker compose down -v || ROLL_IMAGE="$IMAGE_NAME:prev" docker compose down -v
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
            if [[ -z "$IMAGE_NAME" ]]; then
                echo -e "Error: IMAGE is required for build action\n"
                usage
                exit 1
            fi
            build
            ;;
        up)
            if [[ -z "$IMAGE_NAME" ]]; then
                echo -e "Error: IMAGE is required for up action\n"
                usage
                exit 1
            fi
            up
            ;;
        rollout)
            if [[ -z "$3" ]]; then
                echo -e "Error: SERVICE is required for rollout action\n"
                usage
                exit 1
            fi
            rollout
            ;;
        rollback)
            if [[ -z "$3" ]]; then
                echo -e "Error: SERVICE is required for rollback action\n"
                usage
                exit 1
            fi
            rollback
            ;;
        down)
            if [[ -z "$IMAGE_NAME" ]]; then
                echo -e "Error: IMAGE is required for down action\n"
                usage
                exit 1
            fi
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