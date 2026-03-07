#!/bin/sh
set -eu

REQUIRED_APPROVAL="APPROVE_FEISHU_CHAT_ADMIN"

ACTION=""
DOMAIN="feishu"
APP_ID="${FEISHU_APP_ID:-}"
APP_SECRET="${FEISHU_APP_SECRET:-}"

CHAT_ID=""
CHAT_NAME=""
DESCRIPTION=""
OWNER_ID=""
USER_IDS=""
MEMBER_IDS=""
MOBILES=""
EMAILS=""

MEMBER_ID_TYPE="open_id"
CHAT_MODE="private"
APPROVAL_TEXT=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  sh ./scripts/Invoke-FeishuChatAdmin.sh --action <Action> [options]

Actions:
  GetChatInfo | ListMembers | CreateChat | AddMembers | BatchGetIds

Common options:
  --domain <feishu|lark>
  --app-id <id>
  --app-secret <secret>
  --member-id-type <open_id|user_id|union_id>
  --dry-run

CreateChat:
  --chat-name <name>
  --description <text>
  --owner-id <owner_id>
  --user-ids <id1,id2>
  --chat-mode <private|public>
  --approval-text APPROVE_FEISHU_CHAT_ADMIN

AddMembers:
  --chat-id <oc_xxx>
  --member-ids <id1,id2>
  --approval-text APPROVE_FEISHU_CHAT_ADMIN

BatchGetIds:
  --mobiles <mobile1,mobile2>
  --emails <a@b.com,c@d.com>
EOF
}

append_csv() {
  current="${1:-}"
  value="${2:-}"
  if [ -z "$value" ]; then
    printf '%s' "$current"
    return
  fi
  if [ -z "$current" ]; then
    printf '%s' "$value"
  else
    printf '%s,%s' "$current" "$value"
  fi
}

normalize_csv() {
  input="${1:-}"
  if [ -z "$input" ]; then
    printf ''
    return
  fi
  printf '%s' "$input" \
    | tr ';' ',' \
    | tr ',' '\n' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    | sed '/^$/d' \
    | awk 'NF { if (out != "") out = out "," $0; else out = $0 } END { printf "%s", out }'
}

json_escape() {
  printf '%s' "${1:-}" \
    | sed 's/\\/\\\\/g; s/"/\\"/g' \
    | awk 'BEGIN{first=1} {gsub(/\r/, ""); if (!first) printf "\\n"; printf "%s", $0; first=0 }'
}

csv_to_json_array() {
  csv="$(normalize_csv "${1:-}")"
  if [ -z "$csv" ]; then
    printf '[]'
    return
  fi
  out=""
  old_ifs="$IFS"
  IFS=','
  for item in $csv; do
    escaped="$(json_escape "$item")"
    if [ -z "$out" ]; then
      out="\"$escaped\""
    else
      out="$out,\"$escaped\""
    fi
  done
  IFS="$old_ifs"
  printf '[%s]' "$out"
}

extract_json_string() {
  payload="$(printf '%s' "${1:-}" | tr -d '\n\r')"
  key="${2:-}"
  printf '%s' "$payload" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}

extract_json_number() {
  payload="$(printf '%s' "${1:-}" | tr -d '\n\r')"
  key="${2:-}"
  printf '%s' "$payload" | sed -n "s/.*\"$key\"[[:space:]]*:[[:space:]]*\(-\{0,1\}[0-9][0-9]*\).*/\1/p" | head -n 1
}

extract_ids_csv() {
  raw="${1:-}"
  matches="$(printf '%s' "$raw" | tr '\n' ' ' | grep -oE '"(user_id|open_id|union_id)"[[:space:]]*:[[:space:]]*"[^"]+"' || true)"
  if [ -z "$matches" ]; then
    printf ''
    return
  fi
  printf '%s\n' "$matches" \
    | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/' \
    | awk 'NF { if (!seen[$0]++) { if (out != "") out = out "," $0; else out = $0 } } END { printf "%s", out }'
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 2
  fi
}

require_non_empty() {
  value="${1:-}"
  message="${2:-invalid value}"
  if [ -z "$value" ]; then
    echo "$message" >&2
    exit 2
  fi
}

print_preview() {
  action="$1"
  method="$2"
  uri="$3"
  body="$4"

  if [ -z "$body" ]; then
    body="null"
  fi

  cat <<EOF
{
  "action": "$(json_escape "$action")",
  "method": "$(json_escape "$method")",
  "uri": "$(json_escape "$uri")",
  "body": $body,
  "dry_run": true
}
EOF
}

request_token() {
  require_non_empty "$APP_ID" "AppId required. Provide --app-id or FEISHU_APP_ID."
  require_non_empty "$APP_SECRET" "AppSecret required. Provide --app-secret or FEISHU_APP_SECRET."

  auth_uri="$BASE_URL/open-apis/auth/v3/tenant_access_token/internal/"
  auth_body="$(printf '{"app_id":"%s","app_secret":"%s"}' "$(json_escape "$APP_ID")" "$(json_escape "$APP_SECRET")")"
  response="$(curl -sS -X POST "$auth_uri" -H 'Content-Type: application/json; charset=utf-8' -d "$auth_body")"
  code="$(extract_json_number "$response" "code")"

  if [ "$code" != "0" ]; then
    echo "$response" >&2
    exit 1
  fi

  token="$(extract_json_string "$response" "tenant_access_token")"
  require_non_empty "$token" "Failed to parse tenant_access_token from Feishu response."
  printf '%s' "$token"
}

api_call() {
  method="$1"
  uri="$2"
  token="$3"
  body="${4:-}"

  if [ -n "$body" ]; then
    curl -sS -X "$method" "$uri" \
      -H "Authorization: Bearer $token" \
      -H 'Content-Type: application/json; charset=utf-8' \
      -d "$body"
  else
    curl -sS -X "$method" "$uri" \
      -H "Authorization: Bearer $token"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --action)
      ACTION="${2:-}"
      shift 2
      ;;
    --domain)
      DOMAIN="${2:-}"
      shift 2
      ;;
    --app-id)
      APP_ID="${2:-}"
      shift 2
      ;;
    --app-secret)
      APP_SECRET="${2:-}"
      shift 2
      ;;
    --chat-id)
      CHAT_ID="${2:-}"
      shift 2
      ;;
    --chat-name)
      CHAT_NAME="${2:-}"
      shift 2
      ;;
    --description)
      DESCRIPTION="${2:-}"
      shift 2
      ;;
    --owner-id)
      OWNER_ID="${2:-}"
      shift 2
      ;;
    --user-ids)
      USER_IDS="$(append_csv "$USER_IDS" "${2:-}")"
      shift 2
      ;;
    --member-ids)
      MEMBER_IDS="$(append_csv "$MEMBER_IDS" "${2:-}")"
      shift 2
      ;;
    --mobiles)
      MOBILES="$(append_csv "$MOBILES" "${2:-}")"
      shift 2
      ;;
    --emails)
      EMAILS="$(append_csv "$EMAILS" "${2:-}")"
      shift 2
      ;;
    --member-id-type)
      MEMBER_ID_TYPE="${2:-}"
      shift 2
      ;;
    --chat-mode)
      CHAT_MODE="${2:-}"
      shift 2
      ;;
    --approval-text)
      APPROVAL_TEXT="${2:-}"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift 1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$ACTION" in
  GetChatInfo|ListMembers|CreateChat|AddMembers|BatchGetIds)
    ;;
  *)
    echo "Invalid or missing --action." >&2
    usage >&2
    exit 2
    ;;
esac

case "$DOMAIN" in
  feishu)
    BASE_URL="https://open.feishu.cn"
    ;;
  lark)
    BASE_URL="https://open.larksuite.com"
    ;;
  *)
    echo "Invalid --domain. Use feishu or lark." >&2
    exit 2
    ;;
esac

case "$MEMBER_ID_TYPE" in
  open_id|user_id|union_id)
    ;;
  *)
    echo "Invalid --member-id-type. Use open_id, user_id, union_id." >&2
    exit 2
    ;;
esac

case "$CHAT_MODE" in
  private|public)
    ;;
  *)
    echo "Invalid --chat-mode. Use private or public." >&2
    exit 2
    ;;
esac

require_cmd curl
require_cmd awk
require_cmd sed
require_cmd grep
require_cmd tr

USER_IDS="$(normalize_csv "$USER_IDS")"
MEMBER_IDS="$(normalize_csv "$MEMBER_IDS")"
MOBILES="$(normalize_csv "$MOBILES")"
EMAILS="$(normalize_csv "$EMAILS")"

case "$ACTION" in
  GetChatInfo|ListMembers|AddMembers)
    require_non_empty "$CHAT_ID" "--chat-id is required for $ACTION."
    ;;
esac

if [ "$ACTION" = "CreateChat" ]; then
  require_non_empty "$CHAT_NAME" "--chat-name is required for CreateChat."
  require_non_empty "$OWNER_ID" "--owner-id is required for CreateChat."
  require_non_empty "$USER_IDS" "--user-ids is required for CreateChat."
fi

if [ "$ACTION" = "AddMembers" ]; then
  require_non_empty "$MEMBER_IDS" "--member-ids is required for AddMembers."
fi

if [ "$ACTION" = "BatchGetIds" ]; then
  if [ -z "$MOBILES" ] && [ -z "$EMAILS" ]; then
    echo "BatchGetIds requires --mobiles or --emails." >&2
    exit 2
  fi
fi

if [ "$DRY_RUN" -eq 0 ]; then
  if [ "$ACTION" = "CreateChat" ] || [ "$ACTION" = "AddMembers" ]; then
    if [ "$APPROVAL_TEXT" != "$REQUIRED_APPROVAL" ]; then
      echo "Mutating action '$ACTION' requires --approval-text $REQUIRED_APPROVAL" >&2
      exit 2
    fi
  fi
fi

if [ "$ACTION" = "GetChatInfo" ]; then
  uri="$BASE_URL/open-apis/im/v1/chats/$CHAT_ID"
  if [ "$DRY_RUN" -eq 1 ]; then
    print_preview "$ACTION" "GET" "$uri" ""
    exit 0
  fi
  token="$(request_token)"
  response="$(api_call "GET" "$uri" "$token")"
  code="$(extract_json_number "$response" "code")"
  printf '%s\n' "$response"
  if [ -n "$code" ] && [ "$code" != "0" ]; then
    exit 1
  fi
  exit 0
fi

if [ "$ACTION" = "ListMembers" ]; then
  uri="$BASE_URL/open-apis/im/v1/chats/$CHAT_ID/members?page_size=50&member_id_type=$MEMBER_ID_TYPE"
  if [ "$DRY_RUN" -eq 1 ]; then
    print_preview "$ACTION" "GET" "$uri" ""
    exit 0
  fi
  token="$(request_token)"
  response="$(api_call "GET" "$uri" "$token")"
  code="$(extract_json_number "$response" "code")"
  printf '%s\n' "$response"
  if [ -n "$code" ] && [ "$code" != "0" ]; then
    exit 1
  fi
  exit 0
fi

if [ "$ACTION" = "CreateChat" ]; then
  uri="$BASE_URL/open-apis/im/v1/chats?user_id_type=$MEMBER_ID_TYPE"
  users_json="$(csv_to_json_array "$USER_IDS")"
  body="$(printf '{"name":"%s","description":"%s","owner_id":"%s","user_id_list":%s,"chat_mode":"%s"}' "$(json_escape "$CHAT_NAME")" "$(json_escape "$DESCRIPTION")" "$(json_escape "$OWNER_ID")" "$users_json" "$(json_escape "$CHAT_MODE")")"
  if [ "$DRY_RUN" -eq 1 ]; then
    print_preview "$ACTION" "POST" "$uri" "$body"
    exit 0
  fi
  token="$(request_token)"
  response="$(api_call "POST" "$uri" "$token" "$body")"
  code="$(extract_json_number "$response" "code")"
  printf '%s\n' "$response"
  if [ -n "$code" ] && [ "$code" != "0" ]; then
    exit 1
  fi
  exit 0
fi

if [ "$ACTION" = "AddMembers" ]; then
  uri="$BASE_URL/open-apis/im/v1/chats/$CHAT_ID/members?member_id_type=$MEMBER_ID_TYPE"
  member_json="$(csv_to_json_array "$MEMBER_IDS")"
  body="$(printf '{"id_list":%s}' "$member_json")"
  if [ "$DRY_RUN" -eq 1 ]; then
    print_preview "$ACTION" "POST" "$uri" "$body"
    exit 0
  fi
  token="$(request_token)"
  response="$(api_call "POST" "$uri" "$token" "$body")"
  code="$(extract_json_number "$response" "code")"
  printf '%s\n' "$response"
  if [ -n "$code" ] && [ "$code" != "0" ]; then
    exit 1
  fi
  exit 0
fi

if [ "$ACTION" = "BatchGetIds" ]; then
  uri="$BASE_URL/open-apis/contact/v3/users/batch_get_id?user_id_type=$MEMBER_ID_TYPE"
  body="{"
  first=1
  if [ -n "$MOBILES" ]; then
    mobiles_json="$(csv_to_json_array "$MOBILES")"
    body="$body\"mobiles\":$mobiles_json"
    first=0
  fi
  if [ -n "$EMAILS" ]; then
    emails_json="$(csv_to_json_array "$EMAILS")"
    if [ "$first" -eq 0 ]; then
      body="$body,"
    fi
    body="$body\"emails\":$emails_json"
  fi
  body="$body}"

  if [ "$DRY_RUN" -eq 1 ]; then
    print_preview "$ACTION" "POST" "$uri" "$body"
    exit 0
  fi

  token="$(request_token)"
  response="$(api_call "POST" "$uri" "$token" "$body")"
  code="$(extract_json_number "$response" "code")"
  msg="$(extract_json_string "$response" "msg")"
  ids_csv="$(extract_ids_csv "$response")"

  if [ -z "$code" ]; then
    code="999999"
  fi

  cat <<EOF
{
  "action": "BatchGetIds",
  "code": $code,
  "msg": "$(json_escape "$msg")",
  "requested_id_type": "$(json_escape "$MEMBER_ID_TYPE")",
  "resolved_ids_csv": "$(json_escape "$ids_csv")",
  "raw": $response
}
EOF

  if [ "$code" != "0" ]; then
    exit 1
  fi
  exit 0
fi

exit 2
