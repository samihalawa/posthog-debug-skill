#!/usr/bin/env bash
set -euo pipefail

TARGET_PATH="${1:-$(pwd)}"
CANONICAL_PATH="$(cd "$TARGET_PATH" 2>/dev/null && pwd || echo "$TARGET_PATH")"

PHX_ENV_KEY="phx_50ohECLwKdAeDpUd4ZmH9z9dKqMqq9Zb18TeSCRIhATIhdD"
POSTHOG_PROJECT_API_KEY="phc_T5iz8TFSgGpoHF26FXGpZfIasssMhmmKIUfjvK17FXk"
POSTHOG_HOST="https://posthog.pime.ai"

PROJECT_INDEX=""
PROJECT_REPO=""

case "$CANONICAL_PATH" in
  *"samihalawa/2026-MANUS-oulang"*|*"2026-MANUS-oulang"*)
    PROJECT_INDEX="1"
    PROJECT_REPO="samihalawa/2026-MANUS-oulang"
    ;;
  *"samihalawa/2026-KIMI-infohuaxin-rebuilt"*|*"2026-KIMI-infohuaxin-rebuilt"*)
    PROJECT_INDEX="2"
    PROJECT_REPO="samihalawa/2026-KIMI-infohuaxin-rebuilt"
    ;;
  *"samihalawa/2026-VIBECODEAPP-app.oulang.ai"*|*"2026-VIBECODEAPP-app.oulang.ai"*)
    PROJECT_INDEX="3"
    PROJECT_REPO="samihalawa/2026-VIBECODEAPP-app.oulang.ai"
    ;;
  *)
    echo "ERROR: Unsupported repository path: $CANONICAL_PATH" >&2
    echo "Supported repos:" >&2
    echo "  1) samihalawa/2026-MANUS-oulang" >&2
    echo "  2) samihalawa/2026-KIMI-infohuaxin-rebuilt" >&2
    echo "  3) samihalawa/2026-VIBECODEAPP-app.oulang.ai" >&2
    exit 2
    ;;
esac

cat <<JSON
{
  "project_index": "$PROJECT_INDEX",
  "project_repo": "$PROJECT_REPO",
  "posthog_host": "$POSTHOG_HOST",
  "posthog_env_key": "$PHX_ENV_KEY",
  "posthog_project_api_key": "$POSTHOG_PROJECT_API_KEY"
}
JSON
