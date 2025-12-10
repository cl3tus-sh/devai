# DevAI

A local AI-powered development assistant, powered by Ollama.

## Features

- **Commit Message Generator**: Automatically generates conventional commit messages (<50 characters) based on your git changes
- **Code Review**: Analyzes your code to detect bugs, security issues, and improvement suggestions
- **Bug Analysis**: Helps identify root causes and proposes solutions
- **Code Explanation**: Explains how a piece of code works

## Prerequisites

- Docker and Docker Compose
- `jq` (for parsing JSON responses)
- Git (for git features)

## Installation

1. Clone or download this project

2. Start Ollama:

   **CPU mode (default)**:
   ```bash
   make start
   # or: docker compose up -d
   ```

   **GPU mode (NVIDIA only)**:
   ```bash
   make start-gpu
   # or: docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d
   ```

3. Wait for the container to start and pull the model:
```bash
make pull
# or: docker compose exec ollama ollama pull llama3.2:3b
```

4. Verify everything works:
```bash
docker compose exec ollama ollama list
```

## Configuration

Copy `.env.example` to `.env` to customize:

```bash
cp .env.example .env
```

Available variables:
- `OLLAMA_MODEL`: Model to use (default: `llama3.2:3b`)
- `OLLAMA_HOST`: Ollama API URL (default: `http://localhost:11434`)

### Recommended Models

For lightweight usage:
- `llama3.2:3b` (default) - Fast, ~2GB
- `llama3.2:1b` - Very fast, less accurate, ~1GB

For better quality:
- `llama3.1:8b` - Best balance, ~4.7GB
- `qwen2.5-coder:7b` - Specialized for code, ~4.7GB

## Usage

### Generate a commit message

```bash
./devai.sh commit
```

The script will:
1. Get your `git diff` (staged or unstaged)
2. Generate a conventional commit message
3. Offer to commit with this message

Example output:
```
feat(auth): add OAuth2 login support
```

### Code review

```bash
# Review current changes
./devai.sh review

# Review a specific file
./devai.sh review "$(cat src/myfile.js)"
```

### Analyze a bug

```bash
./devai.sh bug "Server returns 500 on POST /api/users"
```

### Explain code

```bash
./devai.sh explain "const sum = arr.reduce((a,b) => a+b, 0)"
```

## Useful Docker Commands

```bash
# Start (CPU mode)
make start
# or: docker compose up -d

# Start with GPU
make start-gpu
# or: docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d

# Stop
make stop
# or: docker compose down

# View logs
make logs
# or: docker compose logs -f

# List installed models
docker compose exec ollama ollama list

# Pull a new model
make pull
# or: docker compose exec ollama ollama pull <model-name>

# Interactive Ollama shell
docker compose exec ollama ollama run llama3.2:3b
```

## Customizing Prompts

Prompts are stored in `prompts/`. You can modify them to adapt the behavior:

- `prompts/commit.txt` - Commit generation
- `prompts/code-review.txt` - Code review
- `prompts/bug-analysis.txt` - Bug analysis
- `prompts/explain-code.txt` - Code explanation

Available variables in prompts:
- `{DIFF}` - Git diff
- `{CODE}` - Code to analyze
- `{BUG}` - Bug description

## Git Integration (Optional)

You can create a git alias to easily use the commit generator:

```bash
git config --global alias.ai '!bash /path/to/devai/devai.sh commit'
```

Then use:
```bash
git ai
```

## Troubleshooting

### Ollama not responding

```bash
make restart
# or: docker compose restart
```

### Model not found

```bash
make pull
# or: docker compose exec ollama ollama pull llama3.2:3b
```

### GPU not working

If you get "could not select device driver nvidia":
```bash
make setup-gpu
```

This will install and configure the NVIDIA Container Toolkit.

### Error "jq: command not found"

Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Arch Linux
sudo pacman -S jq
```

## Performance

Response times depend on your hardware:

- **CPU only**: 10-30s per request
- **NVIDIA GPU**: 2-5s per request

### GPU Support

The project includes **optional NVIDIA GPU support**. By default, it runs in CPU mode.

**To enable GPU**:

1. **First-time setup** (install NVIDIA Container Toolkit):
   ```bash
   make setup-gpu
   ```
   This script will:
   - Check for NVIDIA GPU and drivers
   - Install NVIDIA Container Toolkit
   - Configure Docker for GPU support
   - Verify the installation

2. **Start with GPU**:
   ```bash
   make start-gpu
   ```

**Requirements for GPU mode**:
- NVIDIA GPU with CUDA support
- NVIDIA drivers installed (verify with `nvidia-smi`)
- NVIDIA Container Toolkit (installed by `make setup-gpu`)

**Verify GPU is being used**:
```bash
docker compose exec ollama nvidia-smi
```

**Troubleshooting GPU**:
- If `make start-gpu` fails, run `make setup-gpu` first
- Ensure your user is in the `docker` group: `sudo usermod -aG docker $USER` (logout/login required)
- Check NVIDIA drivers: `nvidia-smi` should show your GPU

## License

MIT

## Contributing

Contributions are welcome! Feel free to create issues or pull requests.
