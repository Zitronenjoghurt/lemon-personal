.PHONY: edit build up down logs

edit:
	npx blowfish-tools

build:
	docker image prune -f
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f
