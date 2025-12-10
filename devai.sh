#!/bin/bash

# devai - AI-powered development assistant using Ollama
# Usage: devai [command] [options]

set -e

# Get script directory to find prompts and .env from anywhere
# Resolve symlinks to find the real script location
if [ -L "${BASH_SOURCE[0]}" ]; then
  SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
else
  SCRIPT_PATH="${BASH_SOURCE[0]}"
fi
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Load .env file if it exists (from script directory)
if [ -f "$SCRIPT_DIR/.env" ]; then
  set -a  # automatically export all variables
  source "$SCRIPT_DIR/.env"
  set +a
fi

OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2:3b}"
PROMPTS_DIR="$SCRIPT_DIR/prompts"

# Configuration
MAX_DIFF_LINES="${MAX_DIFF_LINES:-1000}"  # Configurable via .env, default 1000
MAX_COMMIT_LENGTH="${MAX_COMMIT_LENGTH:-200}"  # Configurable via .env

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if ollama is running
check_ollama() {
  if ! curl -s "${OLLAMA_HOST}/api/tags" >/dev/null 2>&1; then
    echo -e "${RED}Error: Ollama is not running at ${OLLAMA_HOST}${NC}"
    echo "Run: docker-compose up -d"
    exit 1
  fi
}

# Check if model is available
check_model() {
  if ! curl -s "${OLLAMA_HOST}/api/tags" | grep -q "${OLLAMA_MODEL}"; then
    echo -e "${YELLOW}Model ${OLLAMA_MODEL} not found. Pulling...${NC}"
    docker-compose exec ollama ollama pull "${OLLAMA_MODEL}"
  fi
}

# Generate commit message from git diff
commit_message() {
  check_ollama
  check_model

  # Get git diff
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo -e "${RED}Error: Not in a git repository${NC}"
    exit 1
  fi

  DIFF=$(git diff --cached)
  if [ -z "$DIFF" ]; then
    DIFF=$(git diff)
  fi

  if [ -z "$DIFF" ]; then
    echo -e "${YELLOW}No changes detected${NC}"
    exit 0
  fi

  # Truncate diff if it's too large (optional, can be disabled by setting MAX_DIFF_LINES=0)
  if [ "$MAX_DIFF_LINES" -gt 0 ]; then
    DIFF_LINE_COUNT=$(echo "$DIFF" | wc -l)
    if [ "$DIFF_LINE_COUNT" -gt "$MAX_DIFF_LINES" ]; then
      DIFF_TRUNCATED=$(echo "$DIFF" | head -n "$MAX_DIFF_LINES")
      echo -e "${YELLOW}Note: Diff truncated to ${MAX_DIFF_LINES} lines (out of ${DIFF_LINE_COUNT})${NC}"
    else
      DIFF_TRUNCATED="$DIFF"
    fi
  else
    DIFF_TRUNCATED="$DIFF"
  fi

  echo -e "${BLUE}Generating commit message...${NC}"
  echo -e "${YELLOW}Using model: ${OLLAMA_MODEL}${NC}"

  # Use chat API with conventional commits format (with body)
  SYSTEM_PROMPT="You are a git commit message generator following conventional commits format.

Format:
<type>(<optional scope>): <description>

<optional body>

<optional footer>

Rules:
- First line: type(scope): description (max 72 chars, lowercase description, no period)
- Types: feat, fix, docs, style, refactor, perf, test, chore, build, ci
- Body: explain WHAT changed and WHY (wrap at 72 chars per line)
- Body is REQUIRED for non-trivial changes
- Footer: breaking changes, issue references (e.g., 'Fixes #123')

Examples:
feat(auth): add oauth2 login support

Implement OAuth2 authentication flow with Google and GitHub providers.
This replaces the previous basic auth system to improve security.

feat: add user dashboard

Create initial dashboard with user stats and recent activity.
Includes responsive design for mobile devices.

fix(api): handle null user response

Add null check before accessing user properties to prevent crashes
when the API returns an unexpected empty response.

Fixes #42"

  USER_PROMPT="Diff:
${DIFF_TRUNCATED}

Commit message:"

  # Call API with increased token limit for full commit messages
  RESPONSE=$(curl -s "${OLLAMA_HOST}/api/chat" -d "{
    \"model\": \"${OLLAMA_MODEL}\",
    \"messages\": [
      {\"role\": \"system\", \"content\": $(echo "$SYSTEM_PROMPT" | jq -Rs .)},
      {\"role\": \"user\", \"content\": $(echo "$USER_PROMPT" | jq -Rs .)}
    ],
    \"stream\": false,
    \"options\": {
      \"temperature\": 0.2,
      \"top_p\": 0.8,
      \"num_predict\": 200,
      \"repeat_penalty\": 1.1
    }
  }")

  # Extract response from chat API format
  RAW_MESSAGE=$(echo "$RESPONSE" | jq -r '.message.content // .response // empty')

  if [ -z "$RAW_MESSAGE" ]; then
    echo -e "${RED}Error: Empty response from Ollama${NC}"
    echo "Debug: $RESPONSE"
    exit 1
  fi

  # Keep full multi-line message
  MESSAGE="$RAW_MESSAGE"

  # Extract and clean first line
  FIRST_LINE=$(echo "$MESSAGE" | head -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Enforce lowercase after type(scope): on first line
  FIRST_LINE=$(echo "$FIRST_LINE" | sed -E 's/^([a-z]+(\([^)]+\))?): ([A-Z])/\1: \l\3/')

  # Remove trailing period from first line
  FIRST_LINE=$(echo "$FIRST_LINE" | sed 's/\.$//')

  # Validate first line follows conventional commits
  if ! echo "$FIRST_LINE" | grep -qE '^(feat|fix|docs|style|refactor|perf|test|chore|build|ci)'; then
    echo -e "${YELLOW}Warning: First line doesn't follow conventional commits format${NC}"
    echo -e "${YELLOW}Got: ${FIRST_LINE}${NC}"
  fi

  # Reconstruct message with cleaned first line
  if [ "$(echo "$MESSAGE" | wc -l)" -gt 1 ]; then
    REST_OF_MESSAGE=$(echo "$MESSAGE" | tail -n +2)
    MESSAGE=$(printf "%s\n%s" "$FIRST_LINE" "$REST_OF_MESSAGE")
  else
    MESSAGE="$FIRST_LINE"
  fi

  # Display the full formatted commit message
  echo ""
  echo -e "${GREEN}${MESSAGE}${NC}"
  echo ""

  # Optionally commit with this message
  read -p "Use this commit message? (y/N) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    git commit -m "$MESSAGE"
    echo -e "${GREEN}Committed!${NC}"
  fi
}

# Review code
code_review() {
  check_ollama
  check_model

  CODE="$1"
  if [ -z "$CODE" ]; then
    CODE=$(git diff)
    if [ -z "$CODE" ]; then
      echo -e "${RED}Error: No code provided and no git changes found${NC}"
      exit 1
    fi
  fi

  PROMPT_TEMPLATE=$(cat "${PROMPTS_DIR}/code-review.txt")
  PROMPT="${PROMPT_TEMPLATE/\{CODE\}/$CODE}"

  echo -e "${BLUE}Reviewing code...${NC}"

  RESPONSE=$(curl -s "${OLLAMA_HOST}/api/generate" -d "{
    \"model\": \"${OLLAMA_MODEL}\",
    \"prompt\": $(echo "$PROMPT" | jq -Rs .),
    \"stream\": false
  }")

  echo "$RESPONSE" | jq -r '.response'
}

# Analyze bug
bug_analysis() {
  check_ollama
  check_model

  if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide a bug description${NC}"
    exit 1
  fi

  BUG="$1"
  PROMPT_TEMPLATE=$(cat "${PROMPTS_DIR}/bug-analysis.txt")
  PROMPT="${PROMPT_TEMPLATE/\{BUG\}/$BUG}"

  echo -e "${BLUE}Analyzing bug...${NC}"

  RESPONSE=$(curl -s "${OLLAMA_HOST}/api/generate" -d "{
    \"model\": \"${OLLAMA_MODEL}\",
    \"prompt\": $(echo "$PROMPT" | jq -Rs .),
    \"stream\": false
  }")

  echo "$RESPONSE" | jq -r '.response'
}

# Explain code
explain_code() {
  check_ollama
  check_model

  if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide code to explain${NC}"
    exit 1
  fi

  CODE="$1"
  PROMPT_TEMPLATE=$(cat "${PROMPTS_DIR}/explain-code.txt")
  PROMPT="${PROMPT_TEMPLATE/\{CODE\}/$CODE}"

  echo -e "${BLUE}Explaining code...${NC}"

  RESPONSE=$(curl -s "${OLLAMA_HOST}/api/generate" -d "{
    \"model\": \"${OLLAMA_MODEL}\",
    \"prompt\": $(echo "$PROMPT" | jq -Rs .),
    \"stream\": false
  }")

  echo "$RESPONSE" | jq -r '.response'
}

# Show help
show_help() {
  cat <<EOF
  devai - AI-powered development assistant using Ollama

  Usage:
  devai commit              Generate commit message from git diff
  devai review [code]       Review code (uses git diff if no code provided)
  devai bug "description"   Analyze a bug
  devai explain "code"      Explain code
  devai help                Show this help

  Environment Variables:
  OLLAMA_HOST    Ollama API host (default: http://localhost:11434)
  OLLAMA_MODEL   Model to use (default: llama3.2:3b)

  Recommended models:
  qwen2.5-coder:7b (best for code), mistral:7b, codellama:7b

  Examples:
  devai commit
  devai review
  devai bug "Server returns 500 on POST /api/users"
  devai explain "const x = arr.reduce((a,b) => a+b, 0)"

EOF
}

# Main
case "${1:-help}" in
commit)
  commit_message
  ;;
review)
  code_review "$2"
  ;;
bug)
  bug_analysis "$2"
  ;;
explain)
  explain_code "$2"
  ;;
help | --help | -h)
  show_help
  ;;
*)
  echo -e "${RED}Unknown command: $1${NC}"
  show_help
  exit 1
  ;;
esac
