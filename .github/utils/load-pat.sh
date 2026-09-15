#!/usr/bin/env bash

is_sourced() {
  [[ "${BASH_SOURCE[0]}" != "$0" ]]
}

panic() {
  echo "panic: $*" >&2
  return 1 2>/dev/null || exit 1
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    panic "missing required command: $1"
  fi
}

trim_eol() {
  printf '%s' "$1" | tr -d '\r\n'
}

resolve_token_from_secret() {
  local secret_raw parsed token

  secret_raw="$(aws secretsmanager get-secret-value --secret-id "$PAT_SECRET_ARN" --query SecretString --output text)" \
    || panic "unable to read PAT secret from Secrets Manager"
  token="$secret_raw"

  # Support either a raw token secret or a JSON object containing token-like keys.
  if command -v jq >/dev/null 2>&1; then
    parsed="$({
      printf '%s' "$secret_raw" | jq -r 'try (fromjson | .token // .pat // .github_token // .gh_token // .GITHUB_TOKEN // .GH_TOKEN) catch empty'
    } 2>/dev/null || true)"
    if [[ -n "$parsed" && "$parsed" != "null" ]]; then
      token="$parsed"
    fi
  fi

  trim_eol "$token"
}

main() {
  local user_arn user_name policy_doc_json computed_policy_sha gh_token

  require_cmd aws
  require_cmd jq
  require_cmd sha256sum
  require_cmd awk

  if ! is_sourced; then
    panic "load-pat.sh must be sourced (use: source .github/utils/load-pat.sh)"
  fi

  : "${PAT_SECRET_ARN:?PAT_SECRET_ARN is required}"
  : "${PAT_ACCESS_POLICY_SHA:?PAT_ACCESS_POLICY_SHA is required}"

  user_arn="$(aws sts get-caller-identity --query Arn --output text)" \
    || panic "unable to resolve caller identity"
  user_name="$(printf '%s' "$user_arn" | awk -F'/' '{print $NF}')"
  [[ -n "$user_name" ]] || panic "unable to resolve IAM user name from caller identity"

  policy_doc_json="$(aws iam get-user-policy --user-name "$user_name" --policy-name "$AWS_USER_POLICY_NAME" --query PolicyDocument --output json)" \
    || panic "unable to read IAM policy document '$AWS_USER_POLICY_NAME' for user '$user_name'"
  computed_policy_sha="$(printf '%s' "$policy_doc_json" | jq -cS . | sha256sum | awk '{print $1}')" \
    || panic "unable to compute policy SHA"

  if [[ "$computed_policy_sha" != "$PAT_ACCESS_POLICY_SHA" ]]; then
    panic "PAT access policy SHA mismatch"
  fi

  gh_token="$(resolve_token_from_secret)" || panic "unable to resolve GH token from secret"
  [[ -n "$gh_token" ]] || panic "resolved GH token is empty"

  export GH_TOKEN="$gh_token"
}

main "$@"