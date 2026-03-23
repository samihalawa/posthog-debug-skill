#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-$(pwd)}"
CANONICAL_PATH="$(cd "$TARGET_PATH" 2>/dev/null && pwd || echo "$TARGET_PATH")"

DEFAULT_POSTHOG_HOST="https://posthog.pime.ai"
DEFAULT_PERSONAL_API_KEY="phx_14nlonWkAMgasSwJiS7FGNgALNTWpd8Ift94plrlxS49SkTw"
DEFAULT_PROJECT_API_KEY="phc_T5iz8TFSgGpoHF26FXGpZfIasssMhmmKIUfjvK17FXk"
DEFAULT_KIMI_PROJECT_API_KEY="phc_nfd1PeE5qsvbIhipZI2Qp2e5e9VXWKjnas2Lwq9EhuU"

find_env_file() {
  local path="$1"
  local dir=""

  if [[ -d "$path" ]]; then
    dir="$path"
  else
    dir="$(dirname "$path")"
  fi

  while [[ "$dir" != "/" && -n "$dir" ]]; do
    if [[ -f "$dir/.env" ]]; then
      printf '%s\n' "$dir/.env"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  return 1
}

read_env_value() {
  local env_file="$1"
  local key="$2"

  if [[ -z "$env_file" || ! -f "$env_file" ]]; then
    return 1
  fi

  python3 - "$env_file" "$key" <<'PY'
import sys
from pathlib import Path

env_path = Path(sys.argv[1])
target = sys.argv[2]

for line in env_path.read_text().splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "=" not in stripped:
        continue
    key, value = stripped.split("=", 1)
    if key.strip() == target:
        value = value.strip().strip('"').strip("'")
        print(value)
        raise SystemExit(0)

raise SystemExit(1)
PY
}

first_non_empty() {
  for value in "$@"; do
    if [[ -n "${value:-}" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
  done
  return 1
}

PROJECT_INDEX=""
PROJECT_REPO="unknown"
PROJECT_DEFAULT_PROJECT_API_KEY="$DEFAULT_PROJECT_API_KEY"

case "$CANONICAL_PATH" in
  *"2026-MANUS-oulang"*|*"2025-MANUS-oulang-final"*|*"2025-FINAL-AISTUDIO-oulang-final"*|*"2025-FINAL-AISTUDIO-oulang-clerk"*|*"2026-VIBECODEAPP-oulang"*)
    PROJECT_INDEX="1"
    PROJECT_REPO="samihalawa/2026-MANUS-oulang"
    PROJECT_DEFAULT_PROJECT_API_KEY="$DEFAULT_PROJECT_API_KEY"
    ;;
  *"2026-KIMI-infohuaxin-rebuilt"*)
    PROJECT_INDEX="2"
    PROJECT_REPO="samihalawa/2026-KIMI-infohuaxin-rebuilt"
    PROJECT_DEFAULT_PROJECT_API_KEY="$DEFAULT_KIMI_PROJECT_API_KEY"
    ;;
  *"2026-VIBECODEAPP-app.oulang.ai"*|*"app-oulang-ai"*)
    PROJECT_INDEX="3"
    PROJECT_REPO="samihalawa/2026-VIBECODEAPP-app.oulang.ai"
    PROJECT_DEFAULT_PROJECT_API_KEY=""
    ;;
esac

ENV_FILE="$(find_env_file "$CANONICAL_PATH" || true)"

POSTHOG_HOST="$(first_non_empty \
  "$(read_env_value "$ENV_FILE" POSTHOG_HOST || true)" \
  "$(read_env_value "$ENV_FILE" VITE_PUBLIC_POSTHOG_HOST || true)" \
  "$(read_env_value "$ENV_FILE" VITE_POSTHOG_HOST || true)" \
  "$(read_env_value "$ENV_FILE" EXPO_PUBLIC_POSTHOG_HOST || true)" \
  "$DEFAULT_POSTHOG_HOST")"

POSTHOG_PERSONAL_API_KEY="$(first_non_empty \
  "$(read_env_value "$ENV_FILE" POSTHOG_PERSONAL_API_KEY || true)" \
  "$DEFAULT_PERSONAL_API_KEY")"

POSTHOG_PROJECT_API_KEY="$(first_non_empty \
  "$(read_env_value "$ENV_FILE" POSTHOG_PROJECT_API_KEY || true)" \
  "$(read_env_value "$ENV_FILE" VITE_PUBLIC_POSTHOG_KEY || true)" \
  "$(read_env_value "$ENV_FILE" VITE_POSTHOG_KEY || true)" \
  "$(read_env_value "$ENV_FILE" EXPO_PUBLIC_POSTHOG_KEY || true)" \
  "$PROJECT_DEFAULT_PROJECT_API_KEY" || true)"

cat <<JSON
{
  "project_index": "$PROJECT_INDEX",
  "project_repo": "$PROJECT_REPO",
  "env_file": "${ENV_FILE:-}",
  "posthog_host": "$POSTHOG_HOST",
  "posthog_personal_api_key": "$POSTHOG_PERSONAL_API_KEY",
  "posthog_project_api_key": "${POSTHOG_PROJECT_API_KEY:-}"
}
JSON
