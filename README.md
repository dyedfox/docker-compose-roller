# Docker Compose Roller

Bash script that simplifies the rollback of the docker compose services to the previous version.

Imagine a situation when you have custom-built docker image and after some time you rollout it there is need to rollback to previous version with zero downtime.
This script does exactly it! It can handle several custom images - each for the corresponding service.
You can built certain image, up and down the docker compose stack, rollout and rollback you services with no downtime.

## Requirements
Docker rollout plugin installed: https://github.com/Wowu/docker-rollout

## Installation

```bash
cd <your_destination_directory>
curl https://raw.githubusercontent.com/dyedfox/docker-compose-roller/main/roller.sh -O https://raw.githubusercontent.com/dyedfox/docker-compose-roller/main/roller.conf -O
chmod +x roller.sh
```

## Usage

Update the conf file according to your setup
