#!/bin/bash
set -o pipefail
umask 077

# 1. prepare filesystem and runtime defaults
# 2. resolve the update plan and stage server files
# 3. acquire auth tokens when enabled
# 4. parse and exec the final startup command with signal forwarding

export TZ=${TZ:-UTC}

ROOT_DIR=/home/container
SERVER_DIR="$ROOT_DIR/Server"
TMP_BASE="$ROOT_DIR/.tmp"
DOWNLOADER_LAST_OUTPUT=""
STARTUP_TIME=$(date +%s)

SERVER_VERSION=${SERVER_VERSION:-latest}
AUTO_UPDATE="${AUTO_UPDATE-1}"
PATCHLINE=${PATCHLINE:-release}

DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
DOWNLOADER_BIN="${DOWNLOADER_BIN:-$ROOT_DIR/hytale-downloader}"
CREDENTIALS_PATH="${CREDENTIALS_PATH:-$ROOT_DIR/.hytale-downloader-credentials.json}"
DOWNLOADER_OUTPUT_FILTER="Please visit|Path to credentials file|Authorization code:"

MAVEN_BASE_URL="https://maven.hytale.com"
VERSION_PATTERN='^[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-f0-9]+$'
PATCHLINE_PATTERN='^(release|pre-release)$'

BACKUP_BASE="$ROOT_DIR/.server-backups"
SERVER_BACKUP_RETENTION=${SERVER_BACKUP_RETENTION:-2}
[[ "$SERVER_BACKUP_RETENTION" =~ ^[0-9]+$ ]] || SERVER_BACKUP_RETENTION=2
BACKUP_SERVER_FILES=(HytaleServer.jar HytaleServer.aot)
USER_CONFIG_FILES=(config.json bans.json whitelist.json permissions.json)
BACKUP_SERVER_DIRS=()
BACKUP_ROOT_FILES=(Assets.zip)

HYTALE_API_AUTH="${HYTALE_API_AUTH-1}"
HYTALE_PROFILE_UUID="${HYTALE_PROFILE_UUID:-}"
HYTALE_AUTH_STATE_PATH="${HYTALE_AUTH_STATE_PATH:-$ROOT_DIR/.hytale-auth.json}"
HYTALE_OAUTH_CLIENT_ID=hytale-server
HYTALE_OAUTH_SCOPE="openid offline auth:server"
HYTALE_DEVICE_AUTH_URL="https://oauth.accounts.hytale.com/oauth2/device/auth"
HYTALE_TOKEN_URL="https://oauth.accounts.hytale.com/oauth2/token"
HYTALE_PROFILES_URL="https://account-data.hytale.com/my-account/get-profiles"
HYTALE_SESSION_URL="https://sessions.hytale.com/game-session/new"
HYTALE_SESSION_LOGOUT_URL="https://sessions.hytale.com/game-session"
HYTALE_DEVICE_POLL_INTERVAL=5

USE_AOT_CACHE="${USE_AOT_CACHE-0}"
USE_COMPACT_HEADERS="${USE_COMPACT_HEADERS-1}"
ALLOW_OP="${ALLOW_OP-0}"
ACCEPT_EARLY_PLUGINS="${ACCEPT_EARLY_PLUGINS-0}"
DISABLE_SENTRY="${DISABLE_SENTRY-0}"
ENABLE_WORLD_BACKUP="${ENABLE_WORLD_BACKUP-1}"
ENABLE_SERVER_BACKUP="${ENABLE_SERVER_BACKUP-1}"

# normalize toggles: only "1" means enabled
for _tv in AUTO_UPDATE HYTALE_API_AUTH USE_AOT_CACHE USE_COMPACT_HEADERS \
           ALLOW_OP ACCEPT_EARLY_PLUGINS DISABLE_SENTRY \
           ENABLE_WORLD_BACKUP ENABLE_SERVER_BACKUP; do
  [ "${!_tv}" != 1 ] && declare "$_tv=0"
done

RED=$(tput setaf 1 2>/dev/null || echo '')
GREEN=$(tput setaf 2 2>/dev/null || echo '')
YELLOW=$(tput setaf 3 2>/dev/null || echo '')
BLUE=$(tput setaf 4 2>/dev/null || echo '')
CYAN=$(tput setaf 6 2>/dev/null || echo '')
NC=$(tput sgr0 2>/dev/null || echo '')

log() {
  local c="$1"
  shift
  printf "%b\n" "${!c}$*${NC}" >&2
}
log_block() {
  local c="$1"; shift
  local line; for line in "$@"; do log "$c" "$line"; done
}
rmq() { rm -rf "$@" 2>/dev/null || true; }
qerr() { "$@" 2>/dev/null || true; }

die() {
  log RED "$*"
  exit 1
}
startup_abort() {
  log RED "$1"
  log YELLOW "[startup] Plan=$PLAN Patchline=$PATCHLINE Target=${TARGET:-latest}"
  case "$PLAN" in
    downloader)
      if ! creds_valid && [ "$HYTALE_API_AUTH" = 1 ]; then
        log YELLOW "[startup] Downloader requires Hytale authentication. Set HYTALE_API_AUTH=1 and complete device login, or provide credentials at $CREDENTIALS_PATH."
      elif [ -n "$DOWNLOADER_LAST_OUTPUT" ]; then
        log YELLOW "[startup] Downloader output:"
        printf '%s\n' "$DOWNLOADER_LAST_OUTPUT" | tail -20 | sed 's/^/  /' >&2
      else log YELLOW "[startup] Download failed. No output captured from downloader."; fi ;;
    maven) log YELLOW "[startup] Maven download failed. Check network access to $MAVEN_BASE_URL." ;;
  esac
  exit 1
}

trim_file() {
  [ -f "$1" ] || return 1
  sed -e 's/\r//g' -e 's/^[[:space:]]*//; s/[[:space:]]*$//' "$1" | tr -d '\n'
}
valid_patchline() { case "$1" in release | pre-release) echo "$1" ;; *) echo release ;; esac }
valid_version() { [[ -n "$1" && "$1" =~ $VERSION_PATTERN ]]; }
mkd() { mkdir -p "$1" || return 1; }
has_server_jar() { [ -f "${1:-$SERVER_DIR}/HytaleServer.jar" ]; }
has_backup() { [ -d "$PATCH_BACKUP_DIR/$1" ] && has_server_jar "$PATCH_BACKUP_DIR/$1/Server"; }

write_0600() {
  local dest="$1" dir tmp; dir=$(dirname "$dest"); mkd "$dir" || return 1
  tmp=$(mktemp "$dir/.$(basename "$dest").tmp.XXXXXX") || return 1
  chmod 600 "$tmp" 2>/dev/null || { rm -f "$tmp"; return 1; }
  { cat >"$tmp" && mv -f "$tmp" "$dest"; } || { rm -f "$tmp"; return 1; }
  chmod 600 "$dest" 2>/dev/null || true
}

cd "$ROOT_DIR" || die "Failed to cd to $ROOT_DIR"
rm -rf "$TMP_BASE"
mkd "$TMP_BASE" || die "Failed to create $TMP_BASE"
mkd "$SERVER_DIR" || die "Failed to create $SERVER_DIR"
# server jar expects start.sh to exist when using /update
[ -f "$ROOT_DIR/start.sh" ] || touch "$ROOT_DIR/start.sh" 2>/dev/null || true

# migrate legacy layout to Server subdirectory
migrate_layout() {
  [ -f "$ROOT_DIR/HytaleServer.jar" ] || return 0
  if [ -f "$SERVER_DIR/HytaleServer.jar" ]; then
    log YELLOW "[migrate] Both $ROOT_DIR/HytaleServer.jar and $SERVER_DIR/HytaleServer.jar exist; keeping Server/ copy"
    rm -f "$ROOT_DIR/HytaleServer.jar"
  else
    mv "$ROOT_DIR/HytaleServer.jar" "$SERVER_DIR/HytaleServer.jar"
  fi
  log YELLOW "[migrate] Moved HytaleServer.jar to Server/"
  for f in HytaleServer.aot .version .patchline; do
    [ -f "$ROOT_DIR/$f" ] && mv "$ROOT_DIR/$f" "$SERVER_DIR/$f" && log YELLOW "[migrate] Moved $f to Server/"
  done
  local d
  for d in Licenses logs universe earlyplugins builtin worlds mods; do
    [ -d "$ROOT_DIR/$d" ] || continue
    if [ -d "$SERVER_DIR/$d" ]; then
      if [ -z "$(ls -A "$ROOT_DIR/$d" 2>/dev/null)" ] || cp -a -n "$ROOT_DIR/$d/." "$SERVER_DIR/$d/"; then
        rm -rf "$ROOT_DIR/$d"; log GREEN "[migrate] ✓ Removed duplicate $d/"
      else log RED "[migrate] Copy failed; NOT deleting $ROOT_DIR/$d to avoid data loss"; fi
    else
      mv "$ROOT_DIR/$d" "$SERVER_DIR/$d"; log YELLOW "[migrate] Moved $d/ to Server/"
    fi
  done
}
migrate_layout

JAR_VERSION= JAR_PATCHLINE=
parse_manifest() {
  local jar="$1" mf
  JAR_VERSION= JAR_PATCHLINE=
  [ -f "$jar" ] || return 1
  mf=$(unzip -p "$jar" META-INF/MANIFEST.MF 2>/dev/null || true)
  JAR_VERSION=$(printf '%s\n' "$mf" | awk -F': ' 'tolower($1)=="implementation-version"{print $2; exit}' | tr -d '\r\n ')
  JAR_PATCHLINE=$(printf '%s\n' "$mf" | awk -F': ' 'tolower($1)=="implementation-patchline"{print $2; exit}' | tr -d '\r\n ')
}

save_meta() {
  local jar="${1:-$SERVER_DIR/HytaleServer.jar}"
  parse_manifest "$jar" || return 1
  [ -n "$JAR_VERSION" ] && printf '%s' "$JAR_VERSION" >"$SERVER_DIR/.version"
  [ -n "$JAR_PATCHLINE" ] && printf '%s' "$JAR_PATCHLINE" >"$SERVER_DIR/.patchline"
  printf '%s' "$JAR_VERSION"
}

if has_server_jar "$SERVER_DIR"; then
  if ! [ -f "$SERVER_DIR/.version" ] || ! grep -qxE "$VERSION_PATTERN" "$SERVER_DIR/.version" \
    || ! [ -f "$SERVER_DIR/.patchline" ] || ! grep -qxE "$PATCHLINE_PATTERN" "$SERVER_DIR/.patchline"; then
    save_meta "$SERVER_DIR/HytaleServer.jar" >/dev/null 2>&1 || true
  fi
fi

QUIC_BUF_TARGET=2097152
# warns if host UDP buffers are smaller than recommended for QUIC traffic to improve latency
for _qp in "receive:/proc/sys/net/core/rmem_max" "send:/proc/sys/net/core/wmem_max"; do
  _ql="${_qp%%:*}" _qf="${_qp#*:}"
  [ -r "$_qf" ] || continue
  _qv=$(cat "$_qf" 2>/dev/null || echo 0)
  [ "$_qv" -lt "$QUIC_BUF_TARGET" ] 2>/dev/null && log YELLOW "[quic] ✗ UDP $_ql buffer low ($_qv bytes). Set $(basename "$_qf")=$QUIC_BUF_TARGET"
done

QEMU_PREFIX=""
ARCH=$(uname -m)
if [ "$ARCH" = aarch64 ] || [ "$ARCH" = arm64 ]; then
  [ -x /usr/bin/qemu-x86_64-static ] && QEMU_PREFIX=/usr/bin/qemu-x86_64-static
  [ -z "$QEMU_PREFIX" ] && [ -x /usr/bin/qemu-x86_64 ] && QEMU_PREFIX=/usr/bin/qemu-x86_64
  [ -z "$QEMU_PREFIX" ] && log YELLOW "[arch] ARM64 detected and QEMU x86_64 not found; downloader may not run"
fi

DL_CMD=("$DOWNLOADER_BIN")
[ -n "$QEMU_PREFIX" ] && DL_CMD=("$QEMU_PREFIX" "$DOWNLOADER_BIN")
DOWNLOADER_ARGS=(-credentials-path "$CREDENTIALS_PATH")

# http helpers: sets HTTP_CODE/HTTP_BODY/HTTP_NEEDS_REAUTH; ctx="-" skips reauth; retries on 429/5xx
HTTP_CODE= HTTP_BODY= HTTP_NEEDS_REAUTH=0

http_request() {
  local ctx="$1" method="$2" url="$3" mode="$4" outfile="${5:-}"
  shift $(( $# > 5 ? 5 : $# ))
  local bodyf tmp code rc timeout_val retries="${HTTP_MAX_RETRIES:-5}"
  [ "$mode" = file ] && timeout_val="${HTTP_FILE_MAX_TIME:-1800}" || timeout_val="${HTTP_MAX_TIME:-30}"
  [ "$mode" = mem ] && { bodyf=$(mktemp "$TMP_BASE/http.body.XXXXXX") || return 1; }
  [ "$mode" = file ] && tmp="${outfile}.tmp"
  HTTP_NEEDS_REAUTH=0
  local curl_out
  [ "$mode" = mem ] && curl_out="$bodyf" || curl_out="$tmp"
  [ "$mode" = file ] && rm -f "$tmp"
  code=$(curl -sS --location --proto '=https' --tlsv1.2 --request "$method" \
    --connect-timeout "${HTTP_CONNECT_TIMEOUT:-10}" --max-time "$timeout_val" \
    --retry "$retries" --retry-all-errors --retry-delay 2 \
    -A "HytaleServerLauncher/1.0" \
    -o "$curl_out" -w "%{http_code}" "$@" "$url")
  rc=$?
  [ "$rc" -ne 0 ] && code=000
  HTTP_CODE="$code"
  [ "$mode" = mem ] && { HTTP_BODY=$(cat "$bodyf"); rm -f "$bodyf"; }
  if [ "$code" = 401 ]; then
    [ "$ctx" != "-" ] && HTTP_NEEDS_REAUTH=1
  fi
  if [ "$mode" = file ]; then
    [ "$HTTP_CODE" = 200 ] || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$outfile" || { rm -f "$tmp"; return 1; }
    return 0
  fi
  [ "$rc" -eq 0 ] || return 1
  return 0
}
http() {
  local ctx="$1" m="$2" url="$3"
  shift 3
  http_request "$ctx" "$m" "$url" mem "" "$@"
}
http_jq() { printf '%s' "$HTTP_BODY" | jq -r "$1"; }
http_get_file() {
  local ctx="$1" url="$2" out="$3"
  shift 3
  http_request "$ctx" GET "$url" file "$out" "$@"
}
http_authed() {
  local method="$1" url="$2"; shift 2
  http api "$method" "$url" -H "Authorization: Bearer $A_TOK" "$@" >/dev/null
  if [ "$HTTP_NEEDS_REAUTH" = 1 ]; then
    if [ -n "$R_TOK" ] && ! refresh_token_known_expired; then
      if oauth_refresh; then
        auth_save
        creds_write 2>/dev/null || true
        http api "$method" "$url" -H "Authorization: Bearer $A_TOK" "$@" >/dev/null
        [ "$HTTP_CODE" = 200 ] && return 0
      fi
    fi
    [ "$OAUTH_REFRESH_HARD_FAIL" = 1 ] && auth_clear
    return 1
  fi
  [ "$HTTP_CODE" = 200 ]
}

install_downloader() {
  log YELLOW "[installer] Installing downloader"
  local td="$TMP_BASE/downloader"
  rm -rf "$td"; mkd "$td" || return 1
  http_get_file "-" "$DOWNLOADER_URL" "$td/downloader.zip" || { log RED "[installer] Download failed (HTTP $HTTP_CODE)"; rm -rf "$td"; return 1; }
  unzip -o "$td/downloader.zip" -d "$td" >/dev/null 2>&1 || { log RED "[installer] Extraction failed"; rm -rf "$td"; return 1; }
  [ -f "$td/hytale-downloader-linux-amd64" ] || { log RED "[installer] Binary missing"; rm -rf "$td"; return 1; }
  cp "$td/hytale-downloader-linux-amd64" "$DOWNLOADER_BIN" && chmod +x "$DOWNLOADER_BIN" 2>/dev/null || { rm -rf "$td"; return 1; }
  rm -rf "$td"; log GREEN "[installer] ✓ Downloader installed"
}
ensure_downloader() {
  if [ -f "$DOWNLOADER_BIN" ]; then
    if [ "$AUTO_UPDATE" = 1 ]; then
      local out rc
      out=$("${DL_CMD[@]}" "${DOWNLOADER_ARGS[@]}" -check-update 2>&1); rc=$?
      [ "$rc" -ne 0 ] && log YELLOW "[installer] Downloader check failed (exit $rc)"
      echo "$out" | grep -q "A new version is available" && { log YELLOW "[installer] Updating downloader"; install_downloader || log RED "[installer] Failed to update downloader"; }
    fi
    return 0
  else install_downloader; fi
}

downloader_print_version() {
  local pl="$1" out v
  out=$(timeout 600 "${DL_CMD[@]}" "${DOWNLOADER_ARGS[@]}" -patchline "$pl" -print-version -skip-update-check 2>&1) || true
  printf '%s\n' "$out" | grep -E "$DOWNLOADER_OUTPUT_FILTER" | sed "s/.*/  ${CYAN}&${NC}/" >&2 || true
  v=$(printf '%s\n' "$out" | grep -oE '[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[a-f0-9]+' | head -1)
  printf '%s\n' "$v"
}

_downloader_run() {
  local pl="$1" dir="$2" dl_log="$dir/downloader.log" dl_script_cmd
  printf -v dl_script_cmd '%q ' "${DL_CMD[@]}" "${DOWNLOADER_ARGS[@]}" -patchline "$pl" -skip-update-check
  rmq "$dir"/*.zip "$dir/Server"
  (cd "$dir" && script -qfec "timeout ${DOWNLOADER_TIMEOUT:-3600} $dl_script_cmd" "$dl_log" >&2)
}
downloader_fetch_extract() {
  local pl="$1" dir="$2" zip dl_rc retry=0
  mkd "$dir" || return 1
  log BLUE "[update] Downloading $pl via downloader" >&2
  _downloader_run "$pl" "$dir"; dl_rc=$?
  DOWNLOADER_LAST_OUTPUT="$(tail -200 "$dir/downloader.log" 2>/dev/null || true)"
  if [ "$dl_rc" -ne 0 ] && [ -n "$DOWNLOADER_LAST_OUTPUT" ]; then
    if echo "$DOWNLOADER_LAST_OUTPUT" | grep -qF "checksum mismatch"; then
      log YELLOW "[update] Checksum mismatch, retrying"; retry=1
    elif echo "$DOWNLOADER_LAST_OUTPUT" | grep -qF "credentials were created for"; then
      log YELLOW "[update] Credential mismatch, retrying"; rmq "$CREDENTIALS_PATH"; retry=1
    fi
    [ "$retry" = 1 ] && { _downloader_run "$pl" "$dir"; dl_rc=$?; DOWNLOADER_LAST_OUTPUT="$(tail -200 "$dir/downloader.log" 2>/dev/null || true)"; }
  fi
  [ "$dl_rc" -ne 0 ] && { log RED "[update] Downloader failed (exit $dl_rc)"; return 1; }
  zip=$(ls -1t "$dir"/*.zip 2>/dev/null | head -n 1)
  [ -z "$zip" ] || [ ! -f "$zip" ] && { log RED "[update] No zip found after download"; return 1; }
  log BLUE "[update] Extracting and installing" >&2
  unzip -o "$zip" -d "$dir" >&2 || { log RED "[update] Extraction failed"; return 1; }
  [ -d "$dir/Server" ] || { log RED "[update] Server dir not found in extracted files"; return 1; }
  echo "$dir"
}
downloader_assets_only() {
  local td="$TMP_BASE/assets-only" d
  d=$(downloader_fetch_extract "$1" "$td") || { rmq "$td"; return 1; }
  if [ ! -f "$d/Assets.zip" ]; then rmq "$td"; return 1; fi
  cp -f "$d/Assets.zip" "$ROOT_DIR/" && log GREEN "[update] ✓ Assets installed"
  rmq "$td"
}

maven_meta() {
  # caches metadata per patchline to avoid repeat API calls
  local pl="${1:-$PATCHLINE}" cache="$TMP_BASE/maven-metadata-${1:-$PATCHLINE}.xml"
  if [ -f "$cache" ]; then
    HTTP_CODE=200
    cat "$cache"
    return 0
  fi
  http "-" GET "$MAVEN_BASE_URL/$pl/com/hypixel/hytale/Server/maven-metadata.xml" -H "Accept: application/xml" >/dev/null
  [ "$HTTP_CODE" = 200 ] || return 1
  printf '%s' "$HTTP_BODY" | tee "$cache"
}
maven_version_exists() {
  local m
  m=$(maven_meta "$1") && printf '%s' "$m" | grep -Fq "<version>$2</version>"
}
maven_get_latest() {
  local m flat v
  m=$(maven_meta "$1") || return 1
  flat=$(printf '%s' "$m" | tr '\r\n\t' ' ')
  v=$(printf '%s' "$flat" | grep -oE '<version>[[:space:]]*[^<]+' | sed -E 's/<version>[[:space:]]*//' | tail -1)
  v=$(printf '%s' "$v" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
  [ -n "$v" ] && printf '%s' "$v"
}
backup_current() {
  [ "$ENABLE_SERVER_BACKUP" = 1 ] || { log CYAN "[backup] Server backup disabled (ENABLE_SERVER_BACKUP=0)"; return 0; }
  local keep="${1:-}" pl v pdir dest d f bname
  local -a candidates=()
  pl=$(valid_patchline "$(trim_file "$SERVER_DIR/.patchline" 2>/dev/null || echo "$PATCHLINE")")
  v=$(trim_file "$SERVER_DIR/.version" 2>/dev/null || echo "")
  valid_version "$v" && has_server_jar || return 0
  pdir="$BACKUP_BASE/$pl"; dest="$pdir/$v"; mkd "$pdir" || return 0
  for d in "$pdir"/*; do
    [ -d "$d" ] || continue; bname=$(basename "$d")
    [[ "$bname" =~ $VERSION_PATTERN ]] || continue
    [ "$d" = "$dest" ] && continue; [ -n "$keep" ] && [ "$d" = "$keep" ] && continue
    candidates+=("$d")
  done
  if [ "${#candidates[@]}" -ge "$SERVER_BACKUP_RETENTION" ]; then
    local excess=$(( ${#candidates[@]} - SERVER_BACKUP_RETENTION + 1 )) i
    IFS=$'\n' read -r -d '' -a sorted < <(printf '%s\n' "${candidates[@]}" | sort && printf '\0') || true
    for (( i=0; i<excess; i++ )); do rmq "${sorted[$i]}"; done
  fi
  mkd "$dest/Server" || return 0
  for f in "${BACKUP_SERVER_FILES[@]}"; do
    [ -f "$SERVER_DIR/$f" ] || continue
    cp -f "$SERVER_DIR/$f" "$dest/Server/" 2>/dev/null || log YELLOW "[backup] Warning: Failed to backup $f"
  done
  for d in "${BACKUP_SERVER_DIRS[@]}"; do [ -d "$SERVER_DIR/$d" ] && cp -r "$SERVER_DIR/$d" "$dest/Server/" 2>/dev/null || true; done
  for f in "${BACKUP_ROOT_FILES[@]}"; do [ -f "$ROOT_DIR/$f" ] && cp -f "$ROOT_DIR/$f" "$dest/" 2>/dev/null || true; done
  log GREEN "[backup] ✓ .server-backups/$pl/$v/ (retention: $SERVER_BACKUP_RETENTION)"
}

restore_from_dir() {
  local src="$1" d
  [ -f "$src/Server/HytaleServer.jar" ] || return 1
  cp -f "$src/Server/HytaleServer.jar" "$SERVER_DIR/HytaleServer.jar" || return 1
  [ -f "$src/Server/HytaleServer.aot" ] && { cp -f "$src/Server/HytaleServer.aot" "$SERVER_DIR/" || return 1; }
  for d in "${BACKUP_SERVER_DIRS[@]}"; do [ -d "$src/Server/$d" ] && cp -rf "$src/Server/$d" "$SERVER_DIR/" 2>/dev/null || true; done
  [ -f "$src/Assets.zip" ] && cp -f "$src/Assets.zip" "$ROOT_DIR/" 2>/dev/null || true
}

install_extract() {
  local src="$1" f base skip cfg
  [ -d "$src/Server" ] && [ -f "$src/Server/HytaleServer.jar" ] || return 1
  for f in "$src/Server"/*; do
    [ -e "$f" ] || continue; base=$(basename "$f"); skip=0
    for cfg in "${USER_CONFIG_FILES[@]}"; do [ "$base" = "$cfg" ] && [ -f "$SERVER_DIR/$cfg" ] && { skip=1; break; }; done
    [ "$skip" = 1 ] && continue
    if [ -d "$f" ]; then cp -rf "$f" "$SERVER_DIR/" || return 1; else cp -f "$f" "$SERVER_DIR/$base" || return 1; fi
  done
  [ -f "$src/Assets.zip" ] && cp -f "$src/Assets.zip" "$ROOT_DIR/" 2>/dev/null || log YELLOW "[update] Warning: Assets.zip missing"
}

find_backup() {
  local dir="$1" skip="${2:-}" b
  while IFS= read -r b; do
    b="${b%/}"
    [ -n "$b" ] || continue
    [ -n "$skip" ] && [ "$(basename "$b")" = "$skip" ] && continue
    [ -f "$b/Server/HytaleServer.jar" ] && { echo "$b"; return 0; }
  done < <(ls -1d "$dir"/*/ 2>/dev/null | sort -r || true)
  return 1
}

apply_staged() {
  local s="$ROOT_DIR/updater/staging" nv
  [ -f "$s/Server/HytaleServer.jar" ] || return 1
  log BLUE "[update] Applying staged update"; backup_current ""
  install_extract "$s" || return 1; rmq "$ROOT_DIR/updater"
  nv=$(save_meta 2>/dev/null || true); [ -n "$nv" ] && log GREEN "[update] ✓ Applied $nv"
}

STAGED=0
apply_staged && STAGED=1 || true

PATCHLINE=$(valid_patchline "$PATCHLINE")
if [ -f "$SERVER_DIR/config.json" ]; then
  cfgpl=$(jq -r '.Update.Patchline // empty' "$SERVER_DIR/config.json" 2>/dev/null)
  if [ -n "$cfgpl" ]; then
    cfgpl=$(valid_patchline "$cfgpl")
    [ "$cfgpl" != "$PATCHLINE" ] && {
      [ "$STAGED" != 1 ] && log CYAN "[config] Using patchline from config.json: $cfgpl"
      PATCHLINE="$cfgpl"
    }
  fi
fi

EARLY_DIR="$SERVER_DIR/earlyplugins"
EARLY_OFF="$SERVER_DIR/earlyplugins.disabled"
# server loads earlyplugins regardless of flag, so we rename the directory to toggle it
if [ "$ACCEPT_EARLY_PLUGINS" = 1 ]; then
  export ACCEPT_EARLY_PLUGINS_FLAG="--accept-early-plugins"; _ep_from="$EARLY_OFF" _ep_to="$EARLY_DIR"
else export ACCEPT_EARLY_PLUGINS_FLAG=""; _ep_from="$EARLY_DIR" _ep_to="$EARLY_OFF"; fi
if [ -d "$_ep_from" ]; then
  if [ -d "$_ep_to" ]; then
    if cp -a -n "$_ep_from/." "$_ep_to/"; then
      rmq "$_ep_from"
    else
      log RED "[earlyplugins] copy failed, aborting deleting $_ep_from"
    fi
  else
    mv "$_ep_from" "$_ep_to"
  fi
fi
if [ "$ACCEPT_EARLY_PLUGINS" = 1 ]; then
  qerr mkd "$EARLY_DIR"; log GREEN "[earlyplugins] ✓ Enabled"
else log YELLOW "[earlyplugins] ✗ Disabled"; fi

if [ "$ALLOW_OP" = 1 ]; then export ALLOW_OP_FLAG="--allow-op"; else export ALLOW_OP_FLAG=""; fi
if [ "$DISABLE_SENTRY" = 1 ]; then export DISABLE_SENTRY_FLAG="--disable-sentry"; else export DISABLE_SENTRY_FLAG=""; fi

if [ "$ENABLE_WORLD_BACKUP" = 1 ]; then
  export BACKUP_FLAG="--backup --backup-dir ../${BACKUP_DIR:-Backups} --backup-frequency ${BACKUP_FREQUENCY:-30} --backup-max-count ${BACKUP_MAX_COUNT:-5}"
  log GREEN "[backup] ✓ Enabled"
else export BACKUP_FLAG=""; log CYAN "[backup] Disabled"; fi

A_TOK= R_TOK= S_TOK= I_TOK=
A_EXP=0 R_EXP=0 S_EXP=0
OAUTH_REFRESH_HARD_FAIL=0
P_UUID="${HYTALE_PROFILE_UUID:-}" P_NAME=

token_expired() {
  local exp="$1" buf="${2:-0}"
  [[ "$exp" =~ ^[0-9]+$ ]] || return 0; [ "$exp" -le 0 ] && return 0
  [ $(($(date +%s) + buf)) -ge "$exp" ]
}

refresh_token_known_expired() { [[ "${R_EXP:-0}" =~ ^[0-9]+$ ]] && [ "${R_EXP:-0}" -gt 0 ] && token_expired "$R_EXP" 0; }
fmt_exp() {
  local exp="$1" diff; [[ "$exp" =~ ^[0-9]+$ ]] || { echo unknown; return; }
  diff=$((exp - $(date +%s))); [ "$diff" -le 0 ] && { echo expired; return; }
  local d=$((diff/86400)) h=$(((diff%86400)/3600)) m=$(((diff%3600)/60)) s=$((diff%60))
  [ "$d" -gt 0 ] && echo "in ${d}d ${h}h" || { [ "$h" -gt 0 ] && echo "in ${h}h ${m}m" || { [ "$m" -gt 0 ] && echo "in ${m}m ${s}s" || echo "in ${s}s"; }; }
}
auth_clear() {
  A_TOK= R_TOK= S_TOK= I_TOK=; A_EXP=0 R_EXP=0 S_EXP=0
  P_UUID="${HYTALE_PROFILE_UUID:-}"; P_NAME=
  rmq "$HYTALE_AUTH_STATE_PATH" "$CREDENTIALS_PATH"
}
auth_load() {
  [ -f "$HYTALE_AUTH_STATE_PATH" ] || return 1
  chmod 600 "$HYTALE_AUTH_STATE_PATH" 2>/dev/null || true
  local tsv p_uuid p_name
  tsv=$(jq -r '[.refresh_token//"", .access_token//"", .access_expires//0, .refresh_expires//0, .sessionToken//"", .identityToken//"", .session_expires//0, .profile_uuid//"", .profile_name//""] | @tsv' "$HYTALE_AUTH_STATE_PATH" 2>/dev/null) || return 1
  IFS=$'\t' read -r R_TOK A_TOK A_EXP R_EXP S_TOK I_TOK S_EXP p_uuid p_name <<<"$tsv"
  [ -z "$P_UUID" ] && P_UUID="$p_uuid"
  [ -z "$P_NAME" ] && P_NAME="$p_name"
  [ -n "$A_TOK" ] || [ -n "$R_TOK" ]
}
auth_save() {
  local ae=${A_EXP:-0} re=${R_EXP:-0} se=${S_EXP:-0}
  [[ "$ae" =~ ^[0-9]+$ ]] || ae=0; [[ "$re" =~ ^[0-9]+$ ]] || re=0; [[ "$se" =~ ^[0-9]+$ ]] || se=0
  jq -n --arg rt "$R_TOK" --arg at "$A_TOK" --argjson ae "$ae" --argjson re "$re" \
    --arg st "${S_TOK:-}" --arg it "${I_TOK:-}" --argjson se "$se" \
    --arg pu "${P_UUID:-}" --arg pn "${P_NAME:-}" \
    '{refresh_token:$rt,access_token:$at,access_expires:$ae,refresh_expires:$re,sessionToken:$st,identityToken:$it,session_expires:$se,profile_uuid:$pu,profile_name:$pn}' \
    | write_0600 "$HYTALE_AUTH_STATE_PATH" || true
}
creds_load() {
  [ -f "$CREDENTIALS_PATH" ] || return 1
  chmod 600 "$CREDENTIALS_PATH" 2>/dev/null || true
  local tsv rt at ea
  tsv=$(jq -r '[.refresh_token//"", .access_token//"", .expires_at//0] | @tsv' "$CREDENTIALS_PATH" 2>/dev/null) || return 1
  IFS=$'\t' read -r rt at ea <<<"$tsv"
  [[ "$ea" =~ ^[0-9]+$ ]] || ea=0
  [ -n "$rt" ] && R_TOK="$rt"; [ -n "$at" ] && A_TOK="$at"; A_EXP="$ea"
  [ -n "$R_TOK" ]
}
creds_valid() {
  creds_load || return 1; [ -n "$A_TOK" ] || return 1
  [ "$A_EXP" -gt "$(($(date +%s) + 60))" ] 2>/dev/null
}
creds_write() {
  [ -n "$A_TOK" ] && [ -n "$R_TOK" ] || return 1
  local ea
  ea=${A_EXP:-0}
  [[ "$ea" =~ ^[0-9]+$ ]] || ea=0
  jq -n --arg at "$A_TOK" --arg rt "$R_TOK" --argjson ea "$ea" '{access_token:$at,refresh_token:$rt,expires_at:$ea}' \
    | write_0600 "$CREDENTIALS_PATH" || return 1
}

urlencode() { jq -rn --arg v "$1" '$v|@uri'; }

oauth_parse_tokens() {
  local at rt ei rei now
  at=$(http_jq '.access_token // empty')
  [ -n "$at" ] || return 1
  rt=$(http_jq '.refresh_token // empty')
  ei=$(http_jq '.expires_in // 3600')
  rei=$(http_jq '.refresh_expires_in // .refresh_token_expires_in // empty')
  [[ "$ei" =~ ^[0-9]+$ ]] || ei=3600
  now=$(date +%s)
  A_TOK="$at"; A_EXP=$((now + ei))
  if [ -n "$rt" ]; then
    R_TOK="$rt"
    if [[ "$rei" =~ ^[0-9]+$ ]] && [ "$rei" -gt 0 ]; then
      R_EXP=$((now + rei))
    else
      R_EXP=$((now + 2592000))
    fi
  fi
  return 0
}

oauth_refresh() {
  [ -n "$R_TOK" ] || return 1
  OAUTH_REFRESH_HARD_FAIL=0
  local data="client_id=$(urlencode "$HYTALE_OAUTH_CLIENT_ID")&grant_type=refresh_token&refresh_token=$(urlencode "$R_TOK")"
  http "-" POST "$HYTALE_TOKEN_URL" -d "$data" -H "Content-Type: application/x-www-form-urlencoded" >/dev/null
  if [ "$HTTP_CODE" != 200 ]; then
    log YELLOW "[auth] Refresh failed (HTTP $HTTP_CODE)"
    local err errd; err=$(http_jq '.error // empty'); errd=$(http_jq '.error_description // empty')
    [ -n "$err" ] && log YELLOW "[auth] API error: $err"
    [ -n "$errd" ] && log YELLOW "[auth] API message: $errd"
    case "$err" in invalid_grant|invalid_client|unauthorized_client) OAUTH_REFRESH_HARD_FAIL=1 ;; esac
    return 1
  fi
  oauth_parse_tokens
}

oauth_device_flow() {
  # OAuth2 device flow with adaptive polling/backoff for slow_down/429/5xx
  local data="client_id=$(urlencode "$HYTALE_OAUTH_CLIENT_ID")&scope=$(urlencode "$HYTALE_OAUTH_SCOPE")"
  http "-" POST "$HYTALE_DEVICE_AUTH_URL" -d "$data" -H "Content-Type: application/x-www-form-urlencoded" >/dev/null
  [ "$HTTP_CODE" = 200 ] || { log RED "[auth] Device code request failed (HTTP $HTTP_CODE)"; return 1; }
  local dc uc vu interval exp
  dc=$(http_jq '.device_code // empty'); uc=$(http_jq '.user_code // empty')
  vu=$(http_jq '.verification_uri_complete // .verification_uri // empty')
  interval=$(http_jq '.interval // 5'); exp=$(http_jq '.expires_in // 900')
  [ -z "$interval" ] && interval="$HYTALE_DEVICE_POLL_INTERVAL"
  [[ "$interval" =~ ^[0-9]+$ ]] || interval=5; [ "$interval" -lt 1 ] && interval=5
  [[ "$exp" =~ ^[0-9]+$ ]] || exp=900
  [ -z "$dc" ] && { log RED "[auth] Device auth response missing device_code"; return 1; }
  [ -z "$vu" ] && { log RED "[auth] Device auth response missing verification_uri"; return 1; }
  log CYAN "  ═══════════════════════════════════════════════════════════"
  log CYAN "  Please visit: $vu"
  [ -n "$uc" ] && log CYAN "  Or enter code: $uc at https://accounts.hytale.com/device"
  log CYAN "  Waiting for authorization (expires in ${exp}s)..."
  log CYAN "  ═══════════════════════════════════════════════════════════"
  local elapsed=0 poll_data err errd
  poll_data="client_id=$(urlencode "$HYTALE_OAUTH_CLIENT_ID")&grant_type=urn:ietf:params:oauth:grant-type:device_code&device_code=$(urlencode "$dc")"
  while [ "$elapsed" -lt "$exp" ]; do
    sleep "$interval"; elapsed=$((elapsed + interval))
    http "-" POST "$HYTALE_TOKEN_URL" -d "$poll_data" -H "Content-Type: application/x-www-form-urlencoded" >/dev/null
    [ "$HTTP_CODE" = 200 ] && oauth_parse_tokens && { log GREEN "[auth] ✓ OAuth tokens acquired"; return 0; }
    err=$(http_jq '.error // empty'); errd=$(http_jq '.error_description // empty')
    [ "$err" = "authorization_pending" ] && continue
    if [ "$err" = "slow_down" ] || [ "$HTTP_CODE" = 429 ] || [[ "$HTTP_CODE" =~ ^5[0-9][0-9]$ ]]; then
      interval=$((interval + 5)); [ "$interval" -gt 60 ] && interval=60; continue
    fi
    [ "$HTTP_CODE" = 000 ] && continue
    [ "$err" = "access_denied" ] && { log RED "[auth] Authorization denied"; [ -n "$errd" ] && log YELLOW "[auth] $errd"; return 1; }
    [ "$err" = "expired_token" ] || [ "$err" = "invalid_device_code" ] && { log RED "[auth] Device code expired or invalid"; return 1; }
    log RED "[auth] Polling failed: $err (HTTP $HTTP_CODE)"; [ -n "$errd" ] && log YELLOW "[auth] $errd"; return 1
  done
  log RED "[auth] Authorization timed out"; return 1
}

_try_refresh() {
  [ -n "$R_TOK" ] || return 1
  refresh_token_known_expired && { auth_clear; return 1; }
  oauth_refresh && return 0
  if [ "$OAUTH_REFRESH_HARD_FAIL" = 1 ]; then auth_clear; fi
  return 1
}
oauth_ensure() {
  [ -z "${A_TOK:-}" ] && { _try_refresh && return 0; oauth_device_flow; return $?; }
  token_expired "$A_EXP" 60 || return 0
  _try_refresh && return 0
  oauth_device_flow
}

profile_ensure() {
  [ -n "$P_UUID" ] && return 0
  http_authed GET "$HYTALE_PROFILES_URL" || return 1
  P_UUID=$(http_jq '.profiles[0].uuid // .owner // empty')
  P_NAME=$(http_jq '.profiles[0].username // empty')
  [ -n "$P_UUID" ]
}

session_ensure() {
  [ -n "$S_TOK" ] && [ -n "$I_TOK" ] && ! token_expired "$S_EXP" 60 && return 0
  if [ -n "$S_TOK" ]; then
    log BLUE "[auth] Terminating expiring session before refresh"
    http "-" DELETE "$HYTALE_SESSION_LOGOUT_URL" -H "Authorization: Bearer $S_TOK" -H "Content-Type: application/json" >/dev/null 2>&1 || true
  fi
  S_TOK= I_TOK= S_EXP=0
  profile_ensure || { log YELLOW "[auth] profile_ensure failed"; return 1; }
  if ! http_authed POST "$HYTALE_SESSION_URL" -H "Content-Type: application/json" --data "{\"uuid\":\"$P_UUID\"}"; then
    local err_msg; err_msg=$(http_jq '.error_description // .error // .message // empty')
    log YELLOW "[auth] Session request failed (HTTP $HTTP_CODE)"
    [ -n "$err_msg" ] && log YELLOW "[auth] API response: $err_msg"
    case "$HTTP_CODE" in
      400) log RED "[auth] Bad request — verify HYTALE_PROFILE_UUID is valid" ;;
      401) log RED "[auth] Unauthorized — re-authenticate with /auth login device" ;;
      403) log RED "[auth] Forbidden — sign out other devices, wait ~1h for sessions to expire, confirm entitlement" ;;
      404) log RED "[auth] Not found — profile UUID does not exist, check HYTALE_PROFILE_UUID" ;;
    esac
    return 1
  fi
  S_TOK=$(http_jq '.sessionToken // empty'); I_TOK=$(http_jq '.identityToken // empty')
  [ -n "$S_TOK" ] && [ -n "$I_TOK" ] || return 1
  local ea; ea=$(http_jq '.expiresAt // empty')
  S_EXP=$(date -d "$ea" +%s 2>/dev/null || echo 0)
  [ "$S_EXP" -gt 0 ] || S_EXP=$(($(date +%s) + 3600))
  auth_save
}

session_cleanup() {
  [ "$HYTALE_API_AUTH" != 1 ] && return 0
  [ -z "$S_TOK" ] && return 0
  log BLUE "[auth] Cleaning up game session"
  http "-" DELETE "$HYTALE_SESSION_LOGOUT_URL" -H "Authorization: Bearer $S_TOK" -H "Content-Type: application/json" >/dev/null 2>&1 || true
  if [ "$HTTP_CODE" = 200 ] || [ "$HTTP_CODE" = 204 ]; then
    log GREEN "[auth] ✓ Session terminated"
  else log YELLOW "[auth] Session cleanup returned HTTP $HTTP_CODE (non-fatal)"; fi
  S_TOK= I_TOK= S_EXP=0; auth_save
}

_cw() { creds_write && { log GREEN "[auth] ✓ $1"; return 0; }; log RED "[auth] Failed to write credentials file"; return 1; }
ensure_creds() {
  # valid credentials file -> load and refresh existing state -> device flow
  creds_valid && { log GREEN "[auth] ✓ Credentials file valid"; return 0; }
  auth_load || creds_load || true
  if [ -n "$R_TOK" ]; then
    if ! token_expired "$A_EXP" 60; then _cw "Credentials written" && return 0; fi
    log BLUE "[auth] Refreshing OAuth token"
    if _try_refresh; then auth_save; _cw "Credentials refreshed" && return 0; fi
  fi
  if [ "$HYTALE_API_AUTH" = 1 ]; then
    log BLUE "[auth] Starting OAuth device flow"
    if oauth_ensure; then auth_save; _cw "Credentials acquired" && return 0; fi
    log RED "[auth] OAuth device flow failed"
  fi
  [ "$1" = 1 ] && { log RED "[auth] Required credentials not obtained"; return 1; }
  return 0
}

LOCAL_VER=$(trim_file "$SERVER_DIR/.version" 2>/dev/null || echo "")
LOCAL_PL=$(trim_file "$SERVER_DIR/.patchline" 2>/dev/null || echo "")
PATCH_BACKUP_DIR="$BACKUP_BASE/$PATCHLINE"

log CYAN "Current version : ${LOCAL_VER:-none} (${LOCAL_PL:-unknown})"
log CYAN "Active patchline: $PATCHLINE"
log CYAN "Requested build : $SERVER_VERSION"

PLAN=none TARGET= SRC= ENSURE_ASSETS=0 REQUIRE_CREDS=0

_plan_ver() {
  # local > backup > preferred source
  local ver="$1" prefer_downloader="${2:-0}"
  [ -z "$ver" ] && return 1
  if [ "$LOCAL_VER" = "$ver" ] && { [ "$LOCAL_PL" = "$PATCHLINE" ] || [ -z "$LOCAL_PL" ]; }; then PLAN=none; return 0; fi
  if [ "$LOCAL_VER" = "$ver" ] && [ "$LOCAL_PL" != "$PATCHLINE" ]; then PLAN=patchline; TARGET="$ver"; return 0; fi
  if has_backup "$ver"; then PLAN=backup; SRC="$PATCH_BACKUP_DIR/$ver"; TARGET="$ver"; return 0; fi
  if [ "$prefer_downloader" = 1 ]; then
    PLAN=downloader; TARGET="$ver"; REQUIRE_CREDS=1; return 0
  fi
  if maven_version_exists "$PATCHLINE" "$ver"; then
    PLAN=maven; TARGET="$ver"; ENSURE_ASSETS=1; return 0
  fi
  PLAN=downloader; TARGET="$ver"; REQUIRE_CREDS=1; return 0
}

# latest: staged > backup > downloader
# explicit version: staged > backup > maven > downloader
# Sets PLAN (none|patchline|backup|maven|downloader), TARGET, SRC, REQUIRE_CREDS, ENSURE_ASSETS.
plan() {
  PLAN=none TARGET= SRC= ENSURE_ASSETS=0 REQUIRE_CREDS=0
  [ "$STAGED" = 1 ] && { log GREEN "[update] ✓ Staged update applied, skipping download check"; return; }
  local needs=0
  has_server_jar || needs=1
  case "$SERVER_VERSION" in
    latest)
      if [ "$AUTO_UPDATE" != 1 ]; then
        [ "$needs" = 1 ] && { PLAN=downloader; REQUIRE_CREDS=1; return; }
        if [ -n "$LOCAL_PL" ] && [ "$LOCAL_PL" != "$PATCHLINE" ]; then
          local lb; lb=$(find_backup "$PATCH_BACKUP_DIR")
          [ -n "$lb" ] && has_server_jar "$lb/Server" && { PLAN=backup; SRC="$lb"; TARGET=$(basename "$lb"); return; }
          PLAN=downloader; REQUIRE_CREDS=1; return
        fi
        log GREEN "[update] ✓ Server files present"; log CYAN "[update] Updates disabled (AUTO_UPDATE=0)"; return
      fi
      [ -n "$LOCAL_PL" ] && [ "$LOCAL_PL" != "$PATCHLINE" ] && { [ ! -d "$PATCH_BACKUP_DIR" ] || [ -z "$(ls -A "$PATCH_BACKUP_DIR" 2>/dev/null)" ]; } && needs=1
      local maven_latest; maven_latest=$(maven_get_latest "$PATCHLINE" 2>/dev/null || echo "")
      [ -n "$maven_latest" ] && { _plan_ver "$maven_latest" 1; return; }
      [ "$needs" = 1 ] && { PLAN=downloader; REQUIRE_CREDS=1; return; }
      if creds_valid; then
        log YELLOW "[update] Maven latest check failed, falling back to downloader"
        local remote; remote=$(downloader_print_version "$PATCHLINE")
        [ -n "$remote" ] && ! maven_version_exists "$PATCHLINE" "$remote" && { log YELLOW "[update] Downloader reported $remote but not available on $PATCHLINE patchline"; remote=; }
        [ -n "$remote" ] && { _plan_ver "$remote" 1; return; }
        log YELLOW "[update] No valid version found for $PATCHLINE patchline"; PLAN=none; return
      fi
      log YELLOW "[update] Maven latest check failed and no valid credentials, skipping version check"; PLAN=none; return
      ;;
    previous)
      local pb; pb=$(find_backup "$PATCH_BACKUP_DIR" "$LOCAL_VER") || pb=
      if [ -z "$pb" ]; then
        log RED "[backup] No previous backup found in $PATCHLINE"; log YELLOW "[backup] Available:"
        find "$PATCH_BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -printf '    %f\n' 2>/dev/null || echo "    (none)"
        die "STARTUP ABORTED: Previous version not available"
      fi
      TARGET=$(basename "$pb"); log CYAN "[backup] Found previous: $TARGET"
      [ "$LOCAL_VER" = "$TARGET" ] && has_server_jar && { log GREEN "[update] ✓ Already running $TARGET"; log YELLOW "[update] Change SERVER_VERSION to 'latest' to resume updates"; PLAN=none; return; }
      PLAN=backup; SRC="$pb"; return
      ;;
    *)
      TARGET="$SERVER_VERSION"
      [ "$LOCAL_VER" = "$TARGET" ] && has_server_jar && { log GREEN "[update] ✓ Already running $TARGET"; PLAN=none; return; }
      has_backup "$TARGET" && { log CYAN "[backup] Found $TARGET in backups"; PLAN=backup; SRC="$PATCH_BACKUP_DIR/$TARGET"; return; }
      local maven_latest; maven_latest=$(maven_get_latest "$PATCHLINE" 2>/dev/null || echo "")
      [ -n "$maven_latest" ] && [ "$maven_latest" = "$TARGET" ] && { log CYAN "[update] $TARGET is latest on $PATCHLINE, using downloader"; PLAN=downloader; REQUIRE_CREDS=1; return; }
      maven_version_exists "$PATCHLINE" "$TARGET" && { log CYAN "[update] Found $TARGET on Maven ($PATCHLINE)"; PLAN=maven; ENSURE_ASSETS=1; return; }
      local mvn_code="$HTTP_CODE"
      if [ "$mvn_code" = 000 ] || [[ "$mvn_code" =~ ^5[0-9][0-9]$ ]]; then
        log RED "[update] Cannot verify version $TARGET (network error, HTTP $mvn_code)"; die "STARTUP ABORTED: Cannot verify version availability"
      fi
      log RED "[update] Version $TARGET not available on $PATCHLINE patchline"
      log_block YELLOW "[update] Check a different patchline (e.g., pre-release)" "[update] Downloader can only fetch latest" "[update] Use SERVER_VERSION=latest for newest"
      die "STARTUP ABORTED: Explicit version $TARGET not available"
      ;;
  esac
}

apply_plan() {
  local v
  case "$PLAN" in
    none) return 0 ;;
    patchline)
      log BLUE "[update] Switching patchline ${LOCAL_PL:-unknown} -> $PATCHLINE (same version ${TARGET:-unknown})"
      backup_current ""; printf '%s' "$PATCHLINE" >"$SERVER_DIR/.patchline"
      log GREEN "[update] ✓ Patchline updated" ;;
    backup)
      log BLUE "[backup] Restoring ${TARGET:-version} from backup"
      backup_current "$SRC"; restore_from_dir "$SRC" || return 1
      v=$(save_meta 2>/dev/null || true)
      [ -z "$v" ] && [ -n "$TARGET" ] && printf '%s' "$TARGET" >"$SERVER_DIR/.version"
      log GREEN "[backup] ✓ Restored" ;;
    maven)
      log BLUE "[update] Downloading server $TARGET from Maven"; backup_current ""
      if ! http_get_file "-" "$MAVEN_BASE_URL/$PATCHLINE/com/hypixel/hytale/Server/$TARGET/Server-$TARGET.jar" "$SERVER_DIR/HytaleServer.jar"; then
        log YELLOW "[update] Maven download failed, falling back to downloader"; PLAN=downloader; REQUIRE_CREDS=1; apply_plan; return $?
      fi
      v=$(save_meta 2>/dev/null || true); [ -z "$v" ] && printf '%s' "$TARGET" >"$SERVER_DIR/.version"
      log GREEN "[update] ✓ Downloaded server $TARGET"
      if [ "$ENSURE_ASSETS" = 1 ] && [ ! -f "$ROOT_DIR/Assets.zip" ]; then
        log BLUE "[update] Downloading assets via downloader"
        ensure_downloader || true; ensure_creds 0 && downloader_assets_only "$PATCHLINE" || log YELLOW "[update] Warning: Assets download failed"
      fi ;;
    downloader)
      ensure_downloader || return 1; ensure_creds "$REQUIRE_CREDS"
      if ! creds_valid; then
        has_server_jar && { log YELLOW "[auth] Auth failed, running existing server"; PLAN=none; return 0; }
        log RED "[auth] Authentication required for download"; return 1
      fi
      local dl="$TMP_BASE/hytale-download" d dl_ver dl_pl
      d=$(downloader_fetch_extract "$PATCHLINE" "$dl") || {
        rmq "$dl"; has_server_jar && { log YELLOW "[update] Download failed, falling back to existing server"; return 0; }; return 1
      }
      has_server_jar "$d/Server" && { parse_manifest "$d/Server/HytaleServer.jar"; dl_ver="$JAR_VERSION"; dl_pl="$JAR_PATCHLINE"; }
      [ -n "$TARGET" ] && [ "$SERVER_VERSION" != "latest" ] && [ "$dl_ver" != "$TARGET" ] && { log RED "[update] Downloaded $dl_ver != requested $TARGET"; rmq "$dl"; return 1; }
      if [ -n "$dl_ver" ] && [ "$dl_ver" = "$LOCAL_VER" ] && { [ "$dl_pl" = "$LOCAL_PL" ] || [ -z "$LOCAL_PL" ]; }; then
        log GREEN "[update] ✓ Already running latest $dl_ver"
        [ -n "$dl_pl" ] && [ -z "$LOCAL_PL" ] && printf '%s' "$dl_pl" >"$SERVER_DIR/.patchline"
        rmq "$dl"; return 0
      fi
      backup_current ""
      install_extract "$d" || { rmq "$dl"; has_server_jar && { log YELLOW "[update] Extraction failed, falling back to existing server"; return 0; }; return 1; }
      rmq "$dl"; v=$(save_meta 2>/dev/null || true)
      [ -n "$v" ] && log GREEN "[update] ✓ Updated to $v" || log GREEN "[update] ✓ Updated" ;;
    *) log RED "[update] Internal error: unknown PLAN=$PLAN"; return 1 ;;
  esac
}

plan
if [ "$PLAN" != none ]; then
  _pm="[update] Plan: $PLAN"; [ -n "$TARGET" ] && _pm="$_pm (target $TARGET)"
  [ "$REQUIRE_CREDS" = 1 ] && _pm="$_pm [auth required]"; [ "$ENSURE_ASSETS" = 1 ] && _pm="$_pm [assets]"
  log CYAN "$_pm"
fi
apply_plan || startup_abort "STARTUP ABORTED: Failed to prepare server files"

if [ "$USE_AOT_CACHE" = 1 ] && [ -f "$SERVER_DIR/HytaleServer.aot" ]; then
  export AOT_FLAG="-XX:AOTCache=HytaleServer.aot"
  export COMPACT_HEADERS_FLAG=""
  [ "$USE_COMPACT_HEADERS" = 1 ] && log YELLOW "[aot] CompactObjectHeaders disabled (incompatible with AOT)"
else
  export AOT_FLAG=""
  if [ "$USE_COMPACT_HEADERS" = 1 ]; then export COMPACT_HEADERS_FLAG="-XX:+UseCompactObjectHeaders"; else export COMPACT_HEADERS_FLAG=""; fi
fi

if [ "$HYTALE_API_AUTH" = 1 ]; then
  auth_load || creds_load || true; log CYAN "[auth] Preparing server authentication"
  if oauth_ensure && session_ensure; then
    export HYTALE_SERVER_SESSION_TOKEN="$S_TOK" HYTALE_SERVER_IDENTITY_TOKEN="$I_TOK"
    auth_save; creds_write || true
    log GREEN "[auth] ✓ Tokens ready (access $(fmt_exp "$A_EXP"), session $(fmt_exp "$S_EXP"), refresh $(fmt_exp "$R_EXP"))"
  else
    S_TOK= I_TOK= S_EXP=0
    unset HYTALE_SERVER_SESSION_TOKEN HYTALE_SERVER_IDENTITY_TOKEN 2>/dev/null || true
    log YELLOW "[auth] Continuing without pre-acquired tokens (use /auth login device)"
  fi
else
  S_TOK= I_TOK= S_EXP=0
  unset HYTALE_SERVER_SESSION_TOKEN HYTALE_SERVER_IDENTITY_TOKEN 2>/dev/null || true
  log CYAN "[auth] Disabled (use /auth login device)"
fi

STARTUP="${STARTUP:-}"

# support for {{VAR}} placeholders
PARSED=$(printf '%s' "$STARTUP" | sed -E 's/\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}/${\1}/g' | envsubst)

[ -z "$(printf '%s' "$PARSED" | tr -d '[:space:]')" ] && { log RED "[startup] Empty STARTUP command. Refusing to launch."; exit 1; }
cd "$SERVER_DIR" || { log RED "STARTUP ABORTED: Failed to cd to $SERVER_DIR"; exit 1; }
log GREEN "[startup] ✓ Ready in $(( $(date +%s) - STARTUP_TIME ))s"

if [ -n "${STARTUP_JSON:-}" ]; then
  # Preferred path for exact argv handling without shell-style splitting.
  mapfile -d '' -t CMD < <(printf '%s' "$STARTUP_JSON" | jq -j -e 'if type=="array" and all(.[]; type=="string") then .[] + "\u0000" else error("STARTUP_JSON must be a JSON array of strings") end') \
    || { log RED "[startup] STARTUP_JSON must be a JSON array of strings"; exit 1; }
  [ "${#CMD[@]}" -gt 0 ] || { log RED "[startup] STARTUP_JSON produced empty command array"; exit 1; }
else
  mapfile -d '' -t CMD < <(printf '%s\n' "$PARSED" | xargs -r printf '%s\0' 2>/dev/null) \
    || { log RED "[startup] Failed to parse STARTUP command. Use STARTUP_JSON for exact argument handling."; exit 1; }
  [ "${#CMD[@]}" -gt 0 ] || { log RED "[startup] STARTUP command resolved to no arguments."; exit 1; }
fi

set +m 2>/dev/null || true
SHUTTING_DOWN=0
forward_signal_to_pgrp() {
  [ "$SHUTTING_DOWN" = 1 ] && return 0
  SHUTTING_DOWN=1; trap '' TERM INT HUP QUIT
  kill -s "$1" 0 2>/dev/null || true
}
on_signal() { log YELLOW "[shutdown] Caught SIG${1}, forwarding to server"; forward_signal_to_pgrp "$1"; }
trap 'session_cleanup' EXIT
for _sig in TERM INT HUP QUIT; do trap "on_signal $_sig" "$_sig"; done

"${CMD[@]}"
exit $?
