#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail

DEFAULT_ALLOWED_PREFIXES="bug,change,chore,feat"

TITLE=""
BODY=""
BODY_FILE=""
REPO=""
ISSUE_TYPE=""
ALLOWED_PREFIXES="$DEFAULT_ALLOWED_PREFIXES"
SKIP_PREFIX_CHECK=false

LABELS=()
ASSIGNEES=()

usage() {
  cat <<'EOF'
Create a GitHub issue with repo conventions.

Usage:
  create-github-issue.sh --title "change: My title" [--body "..."] [--body-file path] [options]

Required:
  --title <text>                Issue title. Must be prefixed by default (bug|change|chore|feat):

One of:
  --body <text>                 Issue body text
  --body-file <path>            Path to Markdown body file

Optional:
  --repo <owner/name>           Target repo. Defaults to current repo from gh context
  --label <name>                Label to add (repeatable)
  --assignee <login>            Assignee to add (repeatable; use @me for current user)
  --type <name>                 Issue type to set (e.g. Task), if supported by repo
  --allowed-prefixes <csv>      Allowed title prefixes (default: bug,change,chore,feat)
  --skip-prefix-check           Disable title prefix validation
  -h, --help                    Show this help

Environment:
  SECRET_ARN                    AWS Secrets Manager ARN of the PAT secret (required).
  GH_TOKEN                      Optional pre-set GitHub token. If missing, fetched from SECRET_ARN.

Examples:
  create-github-issue.sh \
    --title "change: Switch JWT audience validation" \
    --body-file .github/prompts/plan-switchJwtAudienceToSts.prompt.md \
    --label "change request" \
    --assignee @me \
    --type Task
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
      --label)
        LABELS+=("$2")
        shift 2
        ;;
      --assignee)
        ASSIGNEES+=("$2")
        shift 2
        ;;
      --type)
        ISSUE_TYPE="$2"
        shift 2
        ;;
      --secret-arn)
        SECRET_ARN="$2"
        shift 2
        ;;
      --allowed-prefixes)
        ALLOWED_PREFIXES="$2"
        shift 2
        ;;
      --skip-prefix-check)
        SKIP_PREFIX_CHECK=true
        shift
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

validate_prefix() {
  local title="$1"
  local prefix_csv="$2"
  local item

  IFS=',' read -r -a prefix_items <<< "$prefix_csv"
  for item in "${prefix_items[@]}"; do
    item="$(echo "$item" | xargs)"
    if [[ "$title" == "$item: "* ]]; then
      return 0
    fi
  done

  echo "Issue title must start with one of: $prefix_csv" >&2
  echo "Got: $title" >&2
  return 1
}

resolve_repo() {
  if [[ -z "$REPO" ]]; then
    REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
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

create_issue() {
  local -a cmd
  local issue_url

  cmd=(gh issue create --repo "$REPO" --title "$TITLE")

  if [[ -n "$BODY_FILE" ]]; then
    cmd+=(--body-file "$BODY_FILE")
  else
    cmd+=(--body "$BODY")
  fi

  for label in "${LABELS[@]}"; do
    cmd+=(--label "$label")
  done

  for assignee in "${ASSIGNEES[@]}"; do
    cmd+=(--assignee "$assignee")
  done

  issue_url="$("${cmd[@]}")"
  printf '%s' "$issue_url"
}

set_issue_type_if_requested() {
  local issue_number="$1"
  local owner name issue_id type_id

  if [[ -z "$ISSUE_TYPE" ]]; then
    return 0
  fi

  owner="${REPO%/*}"
  name="${REPO#*/}"

  issue_id="$(gh api graphql -f query="query { repository(owner:\"$owner\", name:\"$name\") { issue(number:$issue_number) { id } } }" --jq '.data.repository.issue.id')"
  type_id="$(gh api graphql -f query="query { repository(owner:\"$owner\", name:\"$name\") { issueTypes(first:100) { nodes { id name } } } }" --jq ".data.repository.issueTypes.nodes[] | select(.name==\"$ISSUE_TYPE\") | .id" 2>/dev/null || true)"

  if [[ -z "$type_id" ]]; then
    echo "Warning: issue type '$ISSUE_TYPE' not found or not supported for $REPO" >&2
    return 0
  fi

  gh api graphql \
    -f query='mutation($issueId:ID!, $issueTypeId:ID!){ updateIssue(input:{id:$issueId, issueTypeId:$issueTypeId}) { issue { number } } }' \
    -f issueId="$issue_id" \
    -f issueTypeId="$type_id" \
    >/dev/null
}

main() {
  local issue_url issue_number

  require_cmd gh
  parse_args "$@"

  : "${SECRET_ARN:?SECRET_ARN is required (set as environment variable)}"

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

  if [[ "$SKIP_PREFIX_CHECK" == false ]]; then
    validate_prefix "$TITLE" "$ALLOWED_PREFIXES"
  fi

  bootstrap_auth
  resolve_repo
  resolve_assignees

  issue_url="$(create_issue)"
  issue_number="${issue_url##*/}"

  set_issue_type_if_requested "$issue_number"

  gh issue view "$issue_number" --repo "$REPO" --json number,title,state,url,labels,assignees --jq '{created:true,repo:"'"$REPO"'",issue_number:.number,issue_url:.url,title:.title,labels:[.labels[].name],assignees:[.assignees[].login]}'
}

main "$@"
