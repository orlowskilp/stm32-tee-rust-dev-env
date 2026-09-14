#!/usr/bin/env bash
set -euo pipefail

DEFAULT_SECRET_ARN="arn:aws:secretsmanager:ap-southeast-1:487692780388:secret:dev/agents/pat-ynoK2Q"

TITLE=""
BODY=""
BODY_FILE=""
REPO=""
BASE_BRANCH="master"
HEAD_BRANCH=""
SECRET_ARN="$DEFAULT_SECRET_ARN"

DRAFT=false
AUTO_PUSH=true
REQUEST_COPILOT_REVIEW=true

LABELS=()
ASSIGNEES=()

usage() {
  cat <<'EOF'
Create or reuse a GitHub PR using repo conventions.

Usage:
  create-github-pr.sh --title "change: My PR" [--body "..."] [--body-file path] [options]

Required:
  --title <text>                PR title

One of:
  --body <text>                 PR body text
  --body-file <path>            Path to Markdown PR body file

Optional:
  --repo <owner/name>           Target repo. Defaults to current repo from gh context
  --base <branch>               Base branch (default: master)
  --head <branch>               Head branch (default: current git branch)
  --label <name>                Label to add (repeatable)
  --assignee <login>            Assignee to add (repeatable; use @me for current user)
  --draft                       Create PR as draft
  --no-push                     Do not push head branch before PR checks/create
  --no-copilot-review           Do not request Copilot reviewer
  --secret-arn <arn>            Secrets Manager ARN storing PAT
  -h, --help                    Show this help

Environment:
  GH_TOKEN                      Optional pre-set GitHub token. If missing, fetched from Secrets Manager.

Behavior:
  - Reuses an existing open PR for the same --head and --base if present.
  - Requests Copilot review by default when possible.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title)
        TITLE="$2"
        shift 2
        ;;
      --body)
        BODY="$2"
        shift 2
        ;;
      --body-file)
        BODY_FILE="$2"
        shift 2
        ;;
      --repo)
        REPO="$2"
        shift 2
        ;;
      --base)
        BASE_BRANCH="$2"
        shift 2
        ;;
      --head)
        HEAD_BRANCH="$2"
        shift 2
        ;;
      --label)
        LABELS+=("$2")
        shift 2
        ;;
      --assignee)
        ASSIGNEES+=("$2")
        shift 2
        ;;
      --draft)
        DRAFT=true
        shift
        ;;
      --no-push)
        AUTO_PUSH=false
        shift
        ;;
      --no-copilot-review)
        REQUEST_COPILOT_REVIEW=false
        shift
        ;;
      --secret-arn)
        SECRET_ARN="$2"
        shift 2
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown argument: $1" >&2
        usage
        exit 1
        ;;
    esac
  done
}

resolve_token_from_secret() {
  local secret_raw parsed token

  secret_raw="$(aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text)"
  token="$secret_raw"

  if command -v jq >/dev/null 2>&1; then
    parsed="$(
      printf '%s' "$secret_raw" | jq -r 'try (fromjson | .token // .pat // .github_token // .gh_token // .GITHUB_TOKEN // .GH_TOKEN) catch empty' 2>/dev/null || true
    )"
    if [[ -n "$parsed" && "$parsed" != "null" ]]; then
      token="$parsed"
    fi
  fi

  printf '%s' "$token" | tr -d '\r\n'
}

bootstrap_auth() {
  if [[ -z "${GH_TOKEN:-}" ]]; then
    require_cmd aws
    GH_TOKEN="$(resolve_token_from_secret)"
    export GH_TOKEN
  fi

  gh auth status >/dev/null
}

resolve_repo_and_head() {
  if [[ -z "$REPO" ]]; then
    REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
  fi

  if [[ -z "$HEAD_BRANCH" ]]; then
    HEAD_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  fi
}

resolve_assignees() {
  local me
  if [[ ${#ASSIGNEES[@]} -eq 0 ]]; then
    return
  fi

  me="$(gh api user --jq .login)"
  for i in "${!ASSIGNEES[@]}"; do
    if [[ "${ASSIGNEES[$i]}" == "@me" ]]; then
      ASSIGNEES[$i]="$me"
    fi
  done
}

push_head_branch_if_needed() {
  if [[ "$AUTO_PUSH" == true ]]; then
    git push -u origin "$HEAD_BRANCH"
  fi
}

find_existing_pr() {
  gh pr list \
    --repo "$REPO" \
    --head "$HEAD_BRANCH" \
    --base "$BASE_BRANCH" \
    --state open \
    --json number,url \
    --jq '.[0] // empty'
}

create_pr() {
  local -a cmd
  local pr_url

  cmd=(gh pr create --repo "$REPO" --base "$BASE_BRANCH" --head "$HEAD_BRANCH" --title "$TITLE")

  if [[ -n "$BODY_FILE" ]]; then
    cmd+=(--body-file "$BODY_FILE")
  else
    cmd+=(--body "$BODY")
  fi

  if [[ "$DRAFT" == true ]]; then
    cmd+=(--draft)
  fi

  for label in "${LABELS[@]}"; do
    cmd+=(--label "$label")
  done

  pr_url="$("${cmd[@]}")"
  printf '%s' "$pr_url"
}

apply_post_create_metadata() {
  local pr_ref="$1"

  if [[ ${#ASSIGNEES[@]} -gt 0 ]]; then
    for assignee in "${ASSIGNEES[@]}"; do
      gh pr edit "$pr_ref" --repo "$REPO" --add-assignee "$assignee" >/dev/null
    done
  fi

  if [[ "$REQUEST_COPILOT_REVIEW" == true ]]; then
    if ! gh pr edit "$pr_ref" --repo "$REPO" --add-reviewer "copilot" >/dev/null 2>&1; then
      echo "Warning: unable to request Copilot review for $pr_ref" >&2
    fi
  fi
}

main() {
  local existing pr_number pr_url created

  require_cmd gh
  require_cmd git
  parse_args "$@"

  if [[ -z "$TITLE" ]]; then
    echo "Missing required argument: --title" >&2
    usage
    exit 1
  fi

  if [[ -z "$BODY" && -z "$BODY_FILE" ]]; then
    echo "Provide one of --body or --body-file" >&2
    usage
    exit 1
  fi

  if [[ -n "$BODY_FILE" && ! -f "$BODY_FILE" ]]; then
    echo "Body file not found: $BODY_FILE" >&2
    exit 1
  fi

  bootstrap_auth
  resolve_repo_and_head
  resolve_assignees
  push_head_branch_if_needed

  existing="$(find_existing_pr)"
  if [[ -n "$existing" ]]; then
    pr_number="$(printf '%s' "$existing" | jq -r '.number')"
    pr_url="$(printf '%s' "$existing" | jq -r '.url')"
    created=false
  else
    pr_url="$(create_pr)"
    pr_number="${pr_url##*/}"
    created=true
  fi

  apply_post_create_metadata "$pr_number"

  gh pr view "$pr_number" --repo "$REPO" --json number,title,url,baseRefName,headRefName,assignees --jq '{created:'"$created"',repo:"'"$REPO"'",pr_number:.number,pr_url:.url,title:.title,base_branch:.baseRefName,head_branch:.headRefName,assignees:[.assignees[].login],copilot_review_requested:'"$REQUEST_COPILOT_REVIEW"'}'
}

main "$@"
