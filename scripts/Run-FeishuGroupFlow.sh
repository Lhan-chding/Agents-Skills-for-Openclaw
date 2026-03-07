#!/bin/sh
set -eu

REQUIRED_APPROVAL="APPROVE_FEISHU_CHAT_ADMIN"

FLOW="CreateAndAdd"
DOMAIN="feishu"
APP_ID="${FEISHU_APP_ID:-}"
APP_SECRET="${FEISHU_APP_SECRET:-}"

CHAT_NAME=""
DESCRIPTION=""
OWNER_ID=""
CREATE_USER_IDS=""

CHAT_ID=""
ADD_MEMBER_IDS=""
ADD_MEMBER_MOBILES=""
ADD_MEMBER_EMAILS=""

MEMBER_ID_TYPE="open_id"
CHAT_MODE="group"
CHAT_TYPE="private"

EXECUTE=0
APPROVAL_TEXT=""

WRITEBACK_DIR=""
WRITEBACK_DAILY_MEMORY=0
DAILY_MEMORY_PATH=""

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
BRIDGE_SCRIPT="$SCRIPT_DIR/Invoke-FeishuChatAdmin.sh"

LAST_STEP_RC=0
LAST_STEP_OK=0
LAST_STEP_OUT=""
LAST_STEP_FILE=""

DRY_STEPS_MD=""
EXEC_STEPS_MD=""
DRY_STEPS_JSON=""
EXEC_STEPS_JSON=""

usage() {
  cat <<'EOF'
Usage:
  sh ./scripts/Run-FeishuGroupFlow.sh [options]

Flow options:
  --flow <CreateAndAdd|CreateOnly|AddOnly>
  --execute
  --approval-text APPROVE_FEISHU_CHAT_ADMIN

Create options:
  --chat-name <name>
  --description <text>
  --owner-id <owner_id>
  --create-user-ids <id1,id2>
  --chat-mode <group>              (legacy private/public is auto-mapped to --chat-type)
  --chat-type <private|public>

Add options:
  --chat-id <oc_xxx>                 (required for AddOnly)
  --add-member-ids <id1,id2>
  --add-member-mobiles <m1,m2>
  --add-member-emails <a@b.com,c@d.com>
  --member-id-type <open_id|user_id|union_id>

Other options:
  --domain <feishu|lark>
  --app-id <id>
  --app-secret <secret>
  --writeback-dir <dir>
  --writeback-daily-memory
  --daily-memory-path <path>
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

merge_csv() {
  left="$(normalize_csv "${1:-}")"
  right="$(normalize_csv "${2:-}")"
  both="$(append_csv "$left" "$right")"
  if [ -z "$both" ]; then
    printf ''
    return
  fi
  printf '%s' "$both" \
    | tr ',' '\n' \
    | sed '/^$/d' \
    | awk 'NF { if (!seen[$0]++) { if (out != "") out = out "," $0; else out = $0 } } END { printf "%s", out }'
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

extract_chat_id() {
  payload="$(printf '%s' "${1:-}" | tr -d '\n\r')"
  printf '%s' "$payload" | sed -n 's/.*"chat_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1
}

extract_ids_csv() {
  raw="${1:-}"
  preferred="${2:-}"

  matches=""
  case "$preferred" in
    open_id|user_id|union_id)
      matches="$(printf '%s' "$raw" | tr '\n' ' ' | grep -oE "\"$preferred\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" || true)"
      ;;
  esac

  if [ -z "$matches" ]; then
    matches="$(printf '%s' "$raw" | tr '\n' ' ' | grep -oE '"(open_id|user_id|union_id)"[[:space:]]*:[[:space:]]*"[^"]+"' || true)"
  fi

  if [ -z "$matches" ]; then
    printf ''
    return
  fi
  printf '%s\n' "$matches" \
    | sed -E 's/.*:[[:space:]]*"([^"]+)"/\1/' \
    | awk 'NF { if (!seen[$0]++) { if (out != "") out = out "," $0; else out = $0 } } END { printf "%s", out }'
}

bool_json() {
  if [ "$1" = "1" ]; then
    printf 'true'
  else
    printf 'false'
  fi
}

classify_failure_reason() {
  text="${1:-}"
  if printf '%s' "$text" | grep -q '99991663'; then
    printf 'permission_scope_missing_or_app_not_approved (code=99991663)'
    return
  fi
  if printf '%s' "$text" | grep -qi 'tenant_access_token'; then
    printf 'tenant_access_token_failed_or_app_secret_invalid'
    return
  fi
  if printf '%s' "$text" | grep -qi 'Path escapes sandbox root'; then
    printf 'sandbox_path_escape_detected_use_workspace_sync'
    return
  fi
  if printf '%s' "$text" | grep -qi 'command not found'; then
    printf 'runtime_not_available_in_sandbox_use_sh_scripts_or_sync_runtime'
    return
  fi
  if printf '%s' "$text" | grep -qi 'chat_id'; then
    printf 'invalid_or_unreachable_chat_id'
    return
  fi
  printf 'api_or_network_failure'
}

append_step() {
  phase="$1"
  action="$2"
  ok="$3"
  file="$4"

  line="- [$action] ok=$ok"
  entry="{\"phase\":\"$(json_escape "$phase")\",\"action\":\"$(json_escape "$action")\",\"ok\":$(bool_json "$ok"),\"output_file\":\"$(json_escape "$file")\"}"

  if [ "$phase" = "dry-run" ]; then
    if [ -z "$DRY_STEPS_MD" ]; then
      DRY_STEPS_MD="$line"
    else
      DRY_STEPS_MD="$DRY_STEPS_MD
$line"
    fi

    if [ -z "$DRY_STEPS_JSON" ]; then
      DRY_STEPS_JSON="$entry"
    else
      DRY_STEPS_JSON="$DRY_STEPS_JSON,$entry"
    fi
  else
    if [ -z "$EXEC_STEPS_MD" ]; then
      EXEC_STEPS_MD="$line"
    else
      EXEC_STEPS_MD="$EXEC_STEPS_MD
$line"
    fi

    if [ -z "$EXEC_STEPS_JSON" ]; then
      EXEC_STEPS_JSON="$entry"
    else
      EXEC_STEPS_JSON="$EXEC_STEPS_JSON,$entry"
    fi
  fi
}

invoke_bridge_step() {
  phase="$1"
  action="$2"
  shift 2

  output_file="$STEP_DIR/${phase}-${action}.json"

  set +e
  sh "$BRIDGE_SCRIPT" "$@" >"$output_file" 2>&1
  rc=$?
  set -e

  out="$(cat "$output_file")"
  code="$(extract_json_number "$out" "code")"

  ok=1
  if [ "$rc" -ne 0 ]; then
    ok=0
  fi
  if [ -n "$code" ] && [ "$code" != "0" ]; then
    ok=0
  fi

  LAST_STEP_RC="$rc"
  LAST_STEP_OK="$ok"
  LAST_STEP_OUT="$out"
  LAST_STEP_FILE="$output_file"

  append_step "$phase" "$action" "$ok" "$output_file"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --flow)
      FLOW="${2:-}"
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
    --create-user-ids)
      CREATE_USER_IDS="$(append_csv "$CREATE_USER_IDS" "${2:-}")"
      shift 2
      ;;
    --chat-id)
      CHAT_ID="${2:-}"
      shift 2
      ;;
    --add-member-ids)
      ADD_MEMBER_IDS="$(append_csv "$ADD_MEMBER_IDS" "${2:-}")"
      shift 2
      ;;
    --add-member-mobiles)
      ADD_MEMBER_MOBILES="$(append_csv "$ADD_MEMBER_MOBILES" "${2:-}")"
      shift 2
      ;;
    --add-member-emails)
      ADD_MEMBER_EMAILS="$(append_csv "$ADD_MEMBER_EMAILS" "${2:-}")"
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
    --chat-type)
      CHAT_TYPE="${2:-}"
      shift 2
      ;;
    --execute)
      EXECUTE=1
      shift 1
      ;;
    --approval-text)
      APPROVAL_TEXT="${2:-}"
      shift 2
      ;;
    --writeback-dir)
      WRITEBACK_DIR="${2:-}"
      shift 2
      ;;
    --writeback-daily-memory)
      WRITEBACK_DAILY_MEMORY=1
      shift 1
      ;;
    --daily-memory-path)
      DAILY_MEMORY_PATH="${2:-}"
      shift 2
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

if [ ! -f "$BRIDGE_SCRIPT" ]; then
  echo "Bridge script not found: $BRIDGE_SCRIPT" >&2
  exit 2
fi

FLOW_CANONICAL="$FLOW"
case "$FLOW" in
  CreateAndAdd|createandadd|create-and-add)
    FLOW_CANONICAL="CreateAndAdd"
    NEED_CREATE=1
    NEED_ADD=1
    ;;
  CreateOnly|createonly|create-only)
    FLOW_CANONICAL="CreateOnly"
    NEED_CREATE=1
    NEED_ADD=0
    ;;
  AddOnly|addonly|add-only)
    FLOW_CANONICAL="AddOnly"
    NEED_CREATE=0
    NEED_ADD=1
    ;;
  *)
    echo "Invalid --flow. Use CreateAndAdd, CreateOnly, AddOnly." >&2
    exit 2
    ;;
esac

case "$DOMAIN" in
  feishu|lark)
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

# Backward compatibility: legacy mode used private/public for chat_mode.
if [ "$NEED_CREATE" -eq 1 ]; then
  case "$CHAT_MODE" in
    private|public)
      if [ "$CHAT_TYPE" = "private" ]; then
        CHAT_TYPE="$CHAT_MODE"
      fi
      CHAT_MODE="group"
      ;;
  esac
fi

case "$CHAT_MODE" in
  group)
    ;;
  *)
    echo "Invalid --chat-mode. Use group." >&2
    exit 2
    ;;
esac

case "$CHAT_TYPE" in
  private|public)
    ;;
  *)
    echo "Invalid --chat-type. Use private or public." >&2
    exit 2
    ;;
esac

CREATE_USER_IDS="$(normalize_csv "$CREATE_USER_IDS")"
ADD_MEMBER_IDS="$(normalize_csv "$ADD_MEMBER_IDS")"
ADD_MEMBER_MOBILES="$(normalize_csv "$ADD_MEMBER_MOBILES")"
ADD_MEMBER_EMAILS="$(normalize_csv "$ADD_MEMBER_EMAILS")"

NEED_BATCH_RESOLVE=0
if [ -n "$ADD_MEMBER_MOBILES" ] || [ -n "$ADD_MEMBER_EMAILS" ]; then
  NEED_BATCH_RESOLVE=1
fi

if [ "$NEED_CREATE" -eq 1 ]; then
  if [ -z "$CHAT_NAME" ]; then
    echo "--chat-name is required for $FLOW_CANONICAL." >&2
    exit 2
  fi
  if [ -z "$OWNER_ID" ]; then
    echo "--owner-id is required for $FLOW_CANONICAL." >&2
    exit 2
  fi
  if [ -z "$CREATE_USER_IDS" ]; then
    echo "--create-user-ids is required for $FLOW_CANONICAL." >&2
    exit 2
  fi
fi

if [ "$NEED_ADD" -eq 1 ]; then
  if [ -z "$ADD_MEMBER_IDS" ] && [ "$NEED_BATCH_RESOLVE" -eq 0 ]; then
    echo "Add flow requires --add-member-ids or --add-member-mobiles/--add-member-emails." >&2
    exit 2
  fi
fi

if [ "$FLOW_CANONICAL" = "AddOnly" ] && [ -z "$CHAT_ID" ]; then
  echo "--chat-id is required for AddOnly." >&2
  exit 2
fi

if [ "$EXECUTE" -eq 1 ] && [ "$APPROVAL_TEXT" != "$REQUIRED_APPROVAL" ]; then
  echo "--execute requires --approval-text $REQUIRED_APPROVAL" >&2
  exit 2
fi

if [ -z "$WRITEBACK_DIR" ]; then
  if [ -d "$HOME/.openclaw/workspace/memory" ]; then
    WRITEBACK_DIR="$HOME/.openclaw/workspace/memory/feishu-group-flow"
  else
    WRITEBACK_DIR="$SCRIPT_DIR/../logs/feishu-group-flow"
  fi
fi
if ! mkdir -p "$WRITEBACK_DIR" 2>/dev/null; then
  fallback_dir="$SCRIPT_DIR/../logs/feishu-group-flow"
  mkdir -p "$fallback_dir"
  echo "WARN: WriteBackDir unavailable. Fallback to: $fallback_dir" >&2
  WRITEBACK_DIR="$fallback_dir"
fi

timestamp="$(date +%Y%m%d-%H%M%S 2>/dev/null || date +%s)"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
report_base="feishu-group-flow-$timestamp"
json_path="$WRITEBACK_DIR/$report_base.json"
md_path="$WRITEBACK_DIR/$report_base.md"
STEP_DIR="$WRITEBACK_DIR/$report_base-steps"
mkdir -p "$STEP_DIR"

final_ok=0
final_reason=""
runtime_chat_id="$CHAT_ID"
runtime_member_ids="$ADD_MEMBER_IDS"
resolved_member_ids=""

DRY_FAILED=0
EXEC_FAILED=0
LAST_FAILURE_TEXT=""

# Dry-run phase
if [ "$NEED_CREATE" -eq 1 ]; then
  invoke_bridge_step "dry-run" "CreateChat" \
    --action CreateChat \
    --domain "$DOMAIN" \
    --app-id "$APP_ID" \
    --app-secret "$APP_SECRET" \
    --chat-name "$CHAT_NAME" \
    --description "$DESCRIPTION" \
    --owner-id "$OWNER_ID" \
    --user-ids "$CREATE_USER_IDS" \
    --member-id-type "$MEMBER_ID_TYPE" \
    --chat-mode "$CHAT_MODE" \
    --chat-type "$CHAT_TYPE" \
    --dry-run
  if [ "$LAST_STEP_OK" != "1" ]; then
    DRY_FAILED=1
    LAST_FAILURE_TEXT="$LAST_STEP_OUT"
  fi
fi

if [ "$NEED_ADD" -eq 1 ] && [ "$NEED_BATCH_RESOLVE" -eq 1 ]; then
  invoke_bridge_step "dry-run" "BatchGetIds" \
    --action BatchGetIds \
    --domain "$DOMAIN" \
    --app-id "$APP_ID" \
    --app-secret "$APP_SECRET" \
    --mobiles "$ADD_MEMBER_MOBILES" \
    --emails "$ADD_MEMBER_EMAILS" \
    --member-id-type "$MEMBER_ID_TYPE" \
    --dry-run
  if [ "$LAST_STEP_OK" != "1" ]; then
    DRY_FAILED=1
    LAST_FAILURE_TEXT="$LAST_STEP_OUT"
  fi
fi

if [ "$NEED_ADD" -eq 1 ]; then
  dry_chat_id="$CHAT_ID"
  if [ -z "$dry_chat_id" ]; then
    dry_chat_id="<CHAT_ID_FROM_CREATE>"
  fi

  dry_member_ids="$ADD_MEMBER_IDS"
  if [ -z "$dry_member_ids" ]; then
    dry_member_ids="<RESOLVED_IDS_FROM_BATCH>"
  fi

  invoke_bridge_step "dry-run" "AddMembers" \
    --action AddMembers \
    --domain "$DOMAIN" \
    --app-id "$APP_ID" \
    --app-secret "$APP_SECRET" \
    --chat-id "$dry_chat_id" \
    --member-ids "$dry_member_ids" \
    --member-id-type "$MEMBER_ID_TYPE" \
    --dry-run
  if [ "$LAST_STEP_OK" != "1" ]; then
    DRY_FAILED=1
    LAST_FAILURE_TEXT="$LAST_STEP_OUT"
  fi
fi

if [ "$DRY_FAILED" -eq 1 ]; then
  final_ok=0
  final_reason="dry_run_failed: $(classify_failure_reason "$LAST_FAILURE_TEXT")"
elif [ "$EXECUTE" -eq 0 ]; then
  final_ok=0
  final_reason="dry_run_completed_waiting_for_explicit_approval"
else
  # Execute phase
  if [ "$NEED_CREATE" -eq 1 ]; then
    invoke_bridge_step "execute" "CreateChat" \
      --action CreateChat \
      --domain "$DOMAIN" \
      --app-id "$APP_ID" \
      --app-secret "$APP_SECRET" \
      --chat-name "$CHAT_NAME" \
      --description "$DESCRIPTION" \
      --owner-id "$OWNER_ID" \
      --user-ids "$CREATE_USER_IDS" \
      --member-id-type "$MEMBER_ID_TYPE" \
      --chat-mode "$CHAT_MODE" \
      --chat-type "$CHAT_TYPE" \
      --approval-text "$APPROVAL_TEXT"

    if [ "$LAST_STEP_OK" != "1" ]; then
      EXEC_FAILED=1
      LAST_FAILURE_TEXT="$LAST_STEP_OUT"
      final_reason="create_chat_failed: $(classify_failure_reason "$LAST_STEP_OUT")"
    else
      new_chat_id="$(extract_chat_id "$LAST_STEP_OUT")"
      if [ -n "$new_chat_id" ]; then
        runtime_chat_id="$new_chat_id"
      fi
    fi
  fi

  if [ "$NEED_ADD" -eq 1 ] && [ "$NEED_BATCH_RESOLVE" -eq 1 ]; then
    invoke_bridge_step "execute" "BatchGetIds" \
      --action BatchGetIds \
      --domain "$DOMAIN" \
      --app-id "$APP_ID" \
      --app-secret "$APP_SECRET" \
      --mobiles "$ADD_MEMBER_MOBILES" \
      --emails "$ADD_MEMBER_EMAILS" \
      --member-id-type "$MEMBER_ID_TYPE"

    if [ "$LAST_STEP_OK" != "1" ]; then
      EXEC_FAILED=1
      LAST_FAILURE_TEXT="$LAST_STEP_OUT"
      final_reason="batch_get_ids_failed: $(classify_failure_reason "$LAST_STEP_OUT")"
    else
      resolved_csv="$(extract_json_string "$LAST_STEP_OUT" "resolved_ids_csv")"
      if [ -z "$resolved_csv" ]; then
        resolved_csv="$(extract_ids_csv "$LAST_STEP_OUT" "$MEMBER_ID_TYPE")"
      fi
      runtime_member_ids="$(merge_csv "$runtime_member_ids" "$resolved_csv")"
      resolved_member_ids="$runtime_member_ids"
    fi
  fi

  if [ "$NEED_ADD" -eq 1 ]; then
    if [ -z "$runtime_chat_id" ]; then
      EXEC_FAILED=1
      final_reason="add_members_skipped_missing_chat_id"
    elif [ -z "$runtime_member_ids" ]; then
      EXEC_FAILED=1
      final_reason="add_members_skipped_empty_member_set"
    else
      invoke_bridge_step "execute" "AddMembers" \
        --action AddMembers \
        --domain "$DOMAIN" \
        --app-id "$APP_ID" \
        --app-secret "$APP_SECRET" \
        --chat-id "$runtime_chat_id" \
        --member-ids "$runtime_member_ids" \
        --member-id-type "$MEMBER_ID_TYPE" \
        --approval-text "$APPROVAL_TEXT"

      if [ "$LAST_STEP_OK" != "1" ]; then
        EXEC_FAILED=1
        LAST_FAILURE_TEXT="$LAST_STEP_OUT"
        final_reason="add_members_failed: $(classify_failure_reason "$LAST_STEP_OUT")"
      fi
    fi
  fi

  if [ "$EXEC_FAILED" -eq 0 ]; then
    final_ok=1
    final_reason="execution_completed_successfully"
  fi
fi

finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"

if [ -z "$DRY_STEPS_MD" ]; then
  DRY_STEPS_MD="- none"
fi
if [ -z "$EXEC_STEPS_MD" ]; then
  EXEC_STEPS_MD="- none"
fi

if [ -z "$DRY_STEPS_JSON" ]; then
  DRY_STEPS_JSON=""
fi
if [ -z "$EXEC_STEPS_JSON" ]; then
  EXEC_STEPS_JSON=""
fi

cat >"$md_path" <<EOF
# Feishu Group Flow Report

- Flow: $FLOW_CANONICAL
- Execute: $EXECUTE
- Final OK: $final_ok
- Reason: $final_reason
- Chat ID: $runtime_chat_id
- Resolved Member IDs: $resolved_member_ids
- Started: $started_at
- Finished: $finished_at

## Dry Run Steps
$DRY_STEPS_MD

## Execute Steps
$EXEC_STEPS_MD

JSON report: $json_path
EOF

cat >"$json_path" <<EOF
{
  "flow": "$(json_escape "$FLOW_CANONICAL")",
  "execute": $(bool_json "$EXECUTE"),
  "started_at": "$(json_escape "$started_at")",
  "finished_at": "$(json_escape "$finished_at")",
  "domain": "$(json_escape "$DOMAIN")",
  "member_id_type": "$(json_escape "$MEMBER_ID_TYPE")",
  "chat_mode": "$(json_escape "$CHAT_MODE")",
  "inputs": {
    "chat_name": "$(json_escape "$CHAT_NAME")",
    "owner_id": "$(json_escape "$OWNER_ID")",
    "chat_id": "$(json_escape "$CHAT_ID")",
    "create_user_ids": $(csv_to_json_array "$CREATE_USER_IDS"),
    "add_member_ids": $(csv_to_json_array "$ADD_MEMBER_IDS"),
    "add_member_mobiles": $(csv_to_json_array "$ADD_MEMBER_MOBILES"),
    "add_member_emails": $(csv_to_json_array "$ADD_MEMBER_EMAILS")
  },
  "dry_run_steps": [${DRY_STEPS_JSON}],
  "execute_steps": [${EXEC_STEPS_JSON}],
  "final": {
    "ok": $(bool_json "$final_ok"),
    "reason": "$(json_escape "$final_reason")",
    "chat_id": "$(json_escape "$runtime_chat_id")",
    "resolved_member_ids": $(csv_to_json_array "$resolved_member_ids")
  }
}
EOF

if [ "$WRITEBACK_DAILY_MEMORY" -eq 1 ]; then
  target_daily="$DAILY_MEMORY_PATH"
  if [ -z "$target_daily" ]; then
    target_daily="$HOME/.openclaw/workspace/memory/$(date +%Y-%m-%d).md"
  fi

  if [ -f "$target_daily" ]; then
    cat >>"$target_daily" <<EOF

## Feishu Group Flow ($timestamp)
- flow: $FLOW_CANONICAL
- execute: $EXECUTE
- final_ok: $final_ok
- reason: $final_reason
- chat_id: $runtime_chat_id
- resolved_member_ids: $resolved_member_ids
- report_json: $json_path
- report_md: $md_path
EOF
  fi
fi

echo "DryRun completed: $([ "$DRY_FAILED" -eq 0 ] && echo true || echo false)"
echo "Executed: $([ "$EXECUTE" -eq 1 ] && echo true || echo false)"
echo "Final OK: $([ "$final_ok" -eq 1 ] && echo true || echo false)"
echo "Reason: $final_reason"
echo "Chat ID: $runtime_chat_id"
echo "Resolved Member IDs: $resolved_member_ids"
echo "Report JSON: $json_path"
echo "Report MD:   $md_path"

if [ "$EXECUTE" -eq 0 ]; then
  echo ""
  echo "To execute this flow, rerun with:" >&2
  echo "  --execute --approval-text $REQUIRED_APPROVAL" >&2
fi

if [ "$DRY_FAILED" -eq 1 ]; then
  exit 1
fi

if [ "$EXECUTE" -eq 1 ] && [ "$final_ok" -ne 1 ]; then
  exit 1
fi

exit 0
