#!/usr/bin/env bash
#
# html2pdf-karakeep — convert a local HTML file to PDF and upload as an
# asset bookmark to a Karakeep instance.
#
# Usage:
#   html2pdf-karakeep [options] <path-to.html>
#
# Options:
#   -t, --title TITLE       Bookmark title (default: HTML <title> or filename)
#   -u, --url URL           Source URL recorded on the bookmark
#       --tags "a,b,c"      Comma-separated tags to apply after upload
#   -o, --output PDF        Keep the generated PDF at this path
#   -k, --keep              Keep the generated PDF next to the HTML file
#       --instance URL      Karakeep instance (default: $KARAKEEP_URL or built-in)
#       --no-upload         Only convert, skip upload
#   -h, --help              Show this help
#
# Auth: reads KARAKEEP_API_KEY from the environment (typically sourced from
# ~/.bash_aliases_local). Override the instance with KARAKEEP_URL.

set -euo pipefail

DEFAULT_INSTANCE="https://mi-karakeep01.zarquon.space"

usage() {
  sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

die() { echo "error: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Arg parsing
# ---------------------------------------------------------------------------
title=""
source_url=""
tags=""
output_pdf=""
keep_pdf=0
no_upload=0
instance="${KARAKEEP_URL:-$DEFAULT_INSTANCE}"
html_path=""

while (($#)); do
  case "$1" in
    -t|--title)    title="$2"; shift 2 ;;
    -u|--url)      source_url="$2"; shift 2 ;;
    --tags)        tags="$2"; shift 2 ;;
    -o|--output)   output_pdf="$2"; shift 2 ;;
    -k|--keep)     keep_pdf=1; shift ;;
    --instance)    instance="$2"; shift 2 ;;
    --no-upload)   no_upload=1; shift ;;
    -h|--help)     usage 0 ;;
    --)            shift; html_path="${1:-}"; break ;;
    -*)            die "unknown option: $1" ;;
    *)             html_path="$1"; shift ;;
  esac
done

[[ -n "$html_path" ]] || usage 1
[[ -f "$html_path" ]] || die "not a file: $html_path"

# Resolve to absolute path (readlink -f is fine on Linux)
html_abs="$(readlink -f -- "$html_path")"

# ---------------------------------------------------------------------------
# Dependencies
# ---------------------------------------------------------------------------
chrome_bin=""
for c in google-chrome chromium chromium-browser; do
  if command -v "$c" >/dev/null 2>&1; then chrome_bin="$c"; break; fi
done
[[ -n "$chrome_bin" ]] || die "no chrome/chromium found — install one of: google-chrome, chromium"
command -v curl >/dev/null 2>&1 || die "curl not found"

if [[ "$no_upload" -eq 0 ]]; then
  [[ -n "${KARAKEEP_API_KEY:-}" ]] || die "KARAKEEP_API_KEY is not set (source ~/.bash_aliases_local?)"
fi

# ---------------------------------------------------------------------------
# Derive title from <title> tag if not provided
# ---------------------------------------------------------------------------
if [[ -z "$title" ]]; then
  title="$(grep -oPi '(?<=<title>)[^<]+' "$html_abs" 2>/dev/null | head -n1 || true)"
  # Trim whitespace
  title="${title#"${title%%[![:space:]]*}"}"
  title="${title%"${title##*[![:space:]]}"}"
  [[ -n "$title" ]] || title="$(basename -- "$html_abs" .html)"
fi

# ---------------------------------------------------------------------------
# Work paths
# ---------------------------------------------------------------------------
html_dir="$(dirname -- "$html_abs")"
html_base="$(basename -- "$html_abs" .html)"

# Sanitize for temp copy (Chrome handles spaces/unicode, but curl -F chokes on
# some exotic characters — keep a safe ASCII-only name for upload).
safe_slug="$(printf '%s' "$html_base" \
  | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
  | tr -c 'A-Za-z0-9._-' '-' \
  | tr -s '-' \
  | sed 's/^-//; s/-$//' \
  | cut -c1-80)"
[[ -n "$safe_slug" ]] || safe_slug="document"

if [[ -n "$output_pdf" ]]; then
  final_pdf="$output_pdf"
elif [[ "$keep_pdf" -eq 1 ]]; then
  final_pdf="$html_dir/$html_base.pdf"
else
  final_pdf="$(mktemp --suffix=.pdf)"
fi

# Chrome --print-to-pdf happily writes to any path (spaces OK); we use the
# final path directly for conversion.
mkdir -p -- "$(dirname -- "$final_pdf")"

# ---------------------------------------------------------------------------
# Convert
# ---------------------------------------------------------------------------
echo "[1/3] converting: $html_abs"
"$chrome_bin" --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$final_pdf" \
  "file://$html_abs" >/dev/null 2>&1 \
  || die "chrome conversion failed"

[[ -s "$final_pdf" ]] || die "PDF came out empty: $final_pdf"
pdf_size="$(stat -c %s -- "$final_pdf")"
echo "      → $final_pdf ($pdf_size bytes)"

if [[ "$no_upload" -eq 1 ]]; then
  echo "skipping upload (--no-upload)"
  exit 0
fi

# ---------------------------------------------------------------------------
# Upload asset (copy to safe-named temp so multipart works reliably)
# ---------------------------------------------------------------------------
upload_tmp="$(mktemp -d)"
trap 'rm -rf -- "$upload_tmp"' EXIT
upload_path="$upload_tmp/$safe_slug.pdf"
cp -- "$final_pdf" "$upload_path"

echo "[2/3] uploading asset to $instance"
asset_json="$(curl -sS -X POST "$instance/api/v1/assets" \
  -H "Authorization: Bearer $KARAKEEP_API_KEY" \
  -F "file=@$upload_path" \
  -w $'\n%{http_code}')"

http_code="${asset_json##*$'\n'}"
asset_body="${asset_json%$'\n'*}"
[[ "$http_code" == "200" ]] || die "asset upload failed (HTTP $http_code): $asset_body"

asset_id="$(printf '%s' "$asset_body" | grep -oP '"assetId"\s*:\s*"\K[^"]+' | head -n1)"
[[ -n "$asset_id" ]] || die "could not parse assetId from: $asset_body"
echo "      → assetId=$asset_id"

# ---------------------------------------------------------------------------
# Create bookmark
# ---------------------------------------------------------------------------
echo "[3/3] creating bookmark"

# Build JSON safely — title and url need escaping.
json_escape() {
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<<"$1"
}

title_j="$(json_escape "$title")"
filename_j="$(json_escape "$(basename -- "$html_abs" .html).pdf")"
if [[ -n "$source_url" ]]; then
  url_j="$(json_escape "$source_url")"
  source_field=",\"sourceUrl\":$url_j"
else
  source_field=""
fi

bookmark_payload="{\"type\":\"asset\",\"assetType\":\"pdf\",\"assetId\":\"$asset_id\",\"fileName\":$filename_j,\"title\":$title_j$source_field}"

bookmark_json="$(curl -sS -X POST "$instance/api/v1/bookmarks" \
  -H "Authorization: Bearer $KARAKEEP_API_KEY" \
  -H "Content-Type: application/json" \
  -d "$bookmark_payload" \
  -w $'\n%{http_code}')"

http_code="${bookmark_json##*$'\n'}"
bookmark_body="${bookmark_json%$'\n'*}"
[[ "$http_code" == "201" || "$http_code" == "200" ]] \
  || die "bookmark create failed (HTTP $http_code): $bookmark_body"

bookmark_id="$(printf '%s' "$bookmark_body" | grep -oP '"id"\s*:\s*"\K[^"]+' | head -n1)"
[[ -n "$bookmark_id" ]] || die "could not parse bookmark id from: $bookmark_body"
echo "      → bookmarkId=$bookmark_id"

# ---------------------------------------------------------------------------
# Tags (optional)
# ---------------------------------------------------------------------------
if [[ -n "$tags" ]]; then
  tag_array=""
  IFS=',' read -ra tag_list <<<"$tags"
  for t in "${tag_list[@]}"; do
    t_trim="${t#"${t%%[![:space:]]*}"}"
    t_trim="${t_trim%"${t_trim##*[![:space:]]}"}"
    [[ -z "$t_trim" ]] && continue
    t_j="$(json_escape "$t_trim")"
    tag_array+="{\"tagName\":$t_j},"
  done
  tag_array="[${tag_array%,}]"

  tag_resp="$(curl -sS -X POST "$instance/api/v1/bookmarks/$bookmark_id/tags" \
    -H "Authorization: Bearer $KARAKEEP_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"tags\":$tag_array}" \
    -w $'\n%{http_code}')"
  http_code="${tag_resp##*$'\n'}"
  if [[ "$http_code" != "200" && "$http_code" != "201" ]]; then
    echo "warning: tagging returned HTTP $http_code: ${tag_resp%$'\n'*}" >&2
  else
    echo "      → tagged: $tags"
  fi
fi

echo
echo "done."
echo "  PDF:         $final_pdf"
echo "  Asset ID:    $asset_id"
echo "  Bookmark ID: $bookmark_id"
echo "  URL:         $instance/dashboard/preview/$bookmark_id"
