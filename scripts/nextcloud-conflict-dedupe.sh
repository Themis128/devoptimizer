#!/usr/bin/env bash
# nextcloud-conflict-dedupe.sh
#
# Clears Nextcloud Android "File upload conflict" notification floods by
# moving the conflicting server-side copies into Conflicts-Archive/ so the
# phone re-uploads its local version cleanly on the next sync.
#
# Loop: read conflict filenames from the phone's notification shade via ADB
# -> find matching files on the server (psql filecache via ssh) -> WebDAV
# MOVE them to Conflicts-Archive/<date>/<original path> -> wait for the
# phone to sync -> repeat until no conflicts remain or no progress.
#
# Nothing is deleted - everything is moved, preserving fileid/versions.
# Skips Conflicts-Archive itself and InstantUpload/null/test_pull (active
# upload target - moving those would fight the client).
#
# Required env:
#   NEXTCLOUD_USER            e.g. tbaltzakis@cloudless.gr
#   NEXTCLOUD_APP_PASSWORD    app token with files:write (create via occ
#                             user:auth-tokens:add)
# Optional env:
#   ADB_SERIAL (default RFCTA0AEKZP), SSH_HOST (default github-omv),
#   MAX_ROUNDS (default 20), SYNC_WAIT (seconds between rounds, default 150)
set -u

ADB="${ADB_PATH:-/c/Users/tbaltzakis/AppData/Local/Android/Sdk/platform-tools/adb.exe}"
SERIAL="${ADB_SERIAL:-RFCTA0AEKZP}"
SSH_HOST="${SSH_HOST:-github-omv}"
PKG="com.nextcloud.client"
BASE='https://cloud.cloudless.gr/remote.php/dav/files/tbaltzakis%40cloudless.gr'
AUTH="${NEXTCLOUD_USER:?set NEXTCLOUD_USER}:${NEXTCLOUD_APP_PASSWORD:?set NEXTCLOUD_APP_PASSWORD}"
MAX_ROUNDS="${MAX_ROUNDS:-20}"
SYNC_WAIT="${SYNC_WAIT:-150}"
ARCHIVE="Conflicts-Archive/$(date +%Y-%m-%d)"
STATE_DIR="$(mktemp -d)"
trap 'rm -rf "$STATE_DIR"' EXIT

declare -A MKCOL_DONE

mkcol() {
    local dir="$1"
    [ -n "${MKCOL_DONE[$dir]:-}" ] && return 0
    MKCOL_DONE[$dir]=1
    curl -s -o /dev/null -u "$AUTH" -X MKCOL "$BASE/$dir"
}

ensure_archive_parents() {
    local dir="$1" acc part
    acc='Conflicts-Archive'
    mkcol "$acc"; acc="$acc/$(date +%Y-%m-%d)"; mkcol "$acc"
    local IFS='/'
    for part in $dir; do
        acc="$acc/$part"; mkcol "$acc"
    done
}

names_from_phone() {
    "$ADB" -s "$SERIAL" shell "dumpsys notification --noredact" 2>/dev/null \
      | grep -oE 'Pick which version to keep of [^)]+' \
      | sed 's/.*keep of //' | /usr/bin/sort -u
}

paths_for_names() {
    # stdin: filenames -> stdout: "path" rows (files/ stripped) on server
    local inlist
    inlist=$(awk "{gsub(/'/,\"''\"); printf \"'%s',\", \$0}" | sed 's/,$//')
    [ -z "$inlist" ] && return 0
    ssh -o BatchMode=yes "$SSH_HOST" \
      "docker exec nextcloud-db psql -U \$(docker exec nextcloud printenv POSTGRES_USER) -d \$(docker exec nextcloud printenv POSTGRES_DB) -t -A -c \"SELECT path FROM oc_filecache WHERE path LIKE 'files/%' AND name IN ($inlist) AND path NOT LIKE 'files/Conflicts-Archive/%' AND path NOT LIKE 'files/%/test_pull/%' AND storage_mtime < EXTRACT(EPOCH FROM NOW()) - 900\"" \
      | sed 's|^files/||' | tr -d '\r' | /usr/bin/sort -u
}

round=0; stale=0
while [ "$round" -lt "$MAX_ROUNDS" ]; do
    round=$((round+1))
    names_from_phone > "$STATE_DIR/names.txt"
    total=$(wc -l < "$STATE_DIR/names.txt" | tr -d ' ')
    echo "[$(date +%H:%M:%S)] round $round: $total conflicted names on phone"
    [ "$total" -eq 0 ] && { echo "DONE: no conflicts left"; break; }

    paths_for_names < "$STATE_DIR/names.txt" > "$STATE_DIR/paths.txt"
    moves=$(wc -l < "$STATE_DIR/paths.txt" | tr -d ' ')
    echo "  server copies to archive: $moves"
    if [ "$moves" -eq 0 ]; then
        stale=$((stale+1))
        [ "$stale" -ge 3 ] && { echo "DONE: no server copies left to move (stale=$stale)"; break; }
    else
        stale=0
        while IFS= read -r p; do
            dir=$(dirname "$p")
            ensure_archive_parents "$dir"
            code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 60 -u "$AUTH" \
              -X MOVE -H "Destination: $BASE/$ARCHIVE/$p" "$BASE/$p")
            [ "$code" = "201" ] || [ "$code" = "204" ] || echo "  MOVE FAIL $code $p"
        done < "$STATE_DIR/paths.txt"
    fi
    echo "  waiting ${SYNC_WAIT}s for phone sync..."
    sleep "$SYNC_WAIT"
done
echo "finished after $round rounds"
