# Rollout

```yaml
services:
  myapp:
    image: ${DEV_IMAGE}
```

```bash
Makefile:rollout
  docker rmi dev_image:prev
  docker tag dev_image:latest dev_image:prev
  docker build . -f Dockerfile.dev -t dev_image:latest
  DEV_IMAGE=dev_image:latest docker rollout whoami
```


# POC - workflow

```bash
docker build . -t custom_image # Будуємо окремо імадж
DEV_IMAGE=custom_image:latest docker compose up -d # Запускаємо цілий стек
docker tag custom_image:latest custom_image:prev # Тегаємо поточний імадж як старий
nano entrypoint.sh # Щось змінюємо тут
docker build . -t custom_image # Збираємо новий імадж, тепер він вже стає - latest
DEV_IMAGE=custom_image:latest docker rollout web # Оновлюємо сервіс web
docker ps
DEV_IMAGE=custom_image:latest docker rollout web2 # Оновлюємо сервіс web2
```

# POC - 

Rollout and rollback non-custom services
roller rollout --no-custom traefik