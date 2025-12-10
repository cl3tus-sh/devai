.PHONY: help start start-gpu setup-gpu stop restart logs pull commit review clean

# Load .env file if it exists
ifneq (,$(wildcard .env))
    include .env
    export
endif

help:
	@echo "DevAI - Makefile commands"
	@echo ""
	@echo "Usage:"
	@echo "  make start       Start Ollama container (CPU mode)"
	@echo "  make start-gpu   Start Ollama container with NVIDIA GPU"
	@echo "  make setup-gpu   Install NVIDIA Container Toolkit (run once)"
	@echo "  make stop        Stop Ollama container"
	@echo "  make restart     Restart Ollama container"
	@echo "  make logs        Show container logs"
	@echo "  make pull        Pull the default model"
	@echo "  make commit      Generate commit message"
	@echo "  make review      Review current changes"
	@echo "  make clean       Remove containers and volumes"

start:
	docker compose up -d
	@echo "Ollama started (CPU mode). Run 'make pull' to download the model if needed."

start-gpu:
	docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
	@echo "Ollama started (GPU mode). Run 'make pull' to download the model if needed."

setup-gpu:
	./setup-gpu.sh

stop:
	docker compose down

restart:
	docker compose restart

logs:
	docker-compose logs -f

pull:
	@echo "Pulling model: $(OLLAMA_MODEL)"
	docker compose exec ollama ollama pull $(OLLAMA_MODEL)

commit:
	./devai.sh commit

review:
	./devai.sh review

clean:
	docker-compose down -v
	@echo "Containers and volumes removed."
