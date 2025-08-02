#!/bin/bash
set -euo pipefail

# ============================================================== 
# Polarity Web custom-script injector
# v1.0.0
# ============================================================== 
# Copies Polarity Web assets from a user-selected Docker image,
# injects custom JavaScript into index.html, and writes the result
# to /app/polarity-web-modified.
# ==============================================================

# ---------- editable defaults ---------------------------------
SCRIPT_FILE="script.js"                   # default JS to inject
VOLUME_PATH="/app/polarity-web-modified"
TEMP_CONTAINER_NAME="polarity-web-app-script-injected-temp"
TMP_DIR="/tmp/polarity-web-tmp"
# --------------------------------------------------------------

# ------------------------------------------------------------------
# Confirm the user wants to run the script
# ------------------------------------------------------------------
echo "Polarity Web injector: copies web assets from a Docker image,"
echo "injects JavaScript into index.html, and stores the result at $VOLUME_PATH."

read -r -p "[?] Do you want to continue? [Y/n] " CONT
CONT=${CONT:-Y}
if [[ ! $CONT =~ ^[Yy]$ ]]; then
  echo "[✘] Aborted by user."
  exit 1
fi

# ------------------------------------------------------------------
# STEP 1 – Select IMAGE_NAME interactively
# ------------------------------------------------------------------
echo "[+] Searching for local images where REPOSITORY contains 'web'..."
docker images | awk 'NR==1 || tolower($1) ~ /web/ {print}'

mapfile -t WEB_IMAGE_IDS < <(
  docker images --format '{{.Repository}} {{.ID}}' \
  | awk 'tolower($1) ~ /web/ {print $2}'
)

IMAGE_NAME=""
if (( ${#WEB_IMAGE_IDS[@]} == 1 )); then
  DEFAULT_IMAGE="${WEB_IMAGE_IDS[0]}"
  echo
  echo "[i] Detected a single matching image:"
  docker images | awk -v id="$DEFAULT_IMAGE" 'NR==1 || $3 == id {print}'
  echo
  read -r -p "[?] Press Enter to use IMAGE_NAME='${DEFAULT_IMAGE}', or type a different image (repo:tag or ID): " reply
  IMAGE_NAME="${reply:-$DEFAULT_IMAGE}"
else
  echo
  read -r -p "[?] Enter IMAGE_NAME (image ID or repository:tag) from the list above: " IMAGE_NAME
  while [[ -z "$IMAGE_NAME" ]]; do
    read -r -p "[?] IMAGE_NAME cannot be empty. Please enter image ID or repository:tag: " IMAGE_NAME
  done
fi

# Validate IMAGE_NAME exists locally
until docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; do
  echo "[!] '$IMAGE_NAME' is not a local image ID or repository:tag."
  read -r -p "[?] Please enter a valid IMAGE_NAME, or Ctrl-C to abort: " IMAGE_NAME
done
echo "[i] Verified Docker image '$IMAGE_NAME' exists."

# ------------------------------------------------------------------
# NEW: STEP 1b – Ask for SCRIPT_FILE to inject
# ------------------------------------------------------------------
echo
read -r -p "[?] JavaScript file to inject [${SCRIPT_FILE}]: " reply_script
SCRIPT_FILE="${reply_script:-$SCRIPT_FILE}"

# Ensure the file exists (loop until it does or user aborts)
while [[ ! -f "$SCRIPT_FILE" ]]; do
  echo "[!] '$SCRIPT_FILE' not found in $(pwd)."
  read -r -p "[?] Enter a valid path to the JavaScript file, or Ctrl-C to abort: " SCRIPT_FILE
done
echo "[i] Using SCRIPT_FILE = $SCRIPT_FILE"

# ------------------------------------------------------------------
# STEP 2 – Prepare temporary workspace
# ------------------------------------------------------------------
echo "[+] Creating temporary workspace at $TMP_DIR ..."
mkdir -p "$TMP_DIR"

echo "[+] Creating temporary container $TEMP_CONTAINER_NAME ..."
docker rm -f "$TEMP_CONTAINER_NAME" >/dev/null 2>&1 || true
docker create --name "$TEMP_CONTAINER_NAME" "$IMAGE_NAME" >/dev/null

echo "[+] Copying /usr/share/caddy from container ..."
docker cp "$TEMP_CONTAINER_NAME":/usr/share/caddy/. "$TMP_DIR"

# ------------------------------------------------------------------
# STEP 3 – Inject custom script into index.html
# ------------------------------------------------------------------
INDEX_FILE="$TMP_DIR/index.html"
if [[ -f "$INDEX_FILE" ]]; then
  echo "[+] Injecting $SCRIPT_FILE into <head> of index.html ..."
  sed -i "/<head>/r $SCRIPT_FILE" "$INDEX_FILE"
else
  echo "[!] index.html not found in $TMP_DIR"
fi

# ------------------------------------------------------------------
# STEP 4 – Copy modified files to persistent volume location
# ------------------------------------------------------------------
echo "[+] Copying modified files to $VOLUME_PATH ..."
mkdir -p "$VOLUME_PATH"
cp -R "$TMP_DIR"/. "$VOLUME_PATH"

# ------------------------------------------------------------------
# STEP 5 – Clean-up
# ------------------------------------------------------------------
echo "[+] Cleaning up ..."
docker rm "$TEMP_CONTAINER_NAME" >/dev/null
rm -rf "$TMP_DIR"

echo "[✔] Done! Modified Polarity Web files are now in $VOLUME_PATH"

cat <<'EOF'

Next steps
----------
1. Open /app/docker-compose.yml
2. Locate the `web:` (or `caddy:`) service definition.
3. Under its `volumes:` section add:

   - /app/polarity-web-modified:/usr/share/caddy:z

4. Restart the stack:

   cd /app && ./down.sh && ./up.sh

If SELinux is enforced, relabel the directory once:

   sudo chcon -Rt svirt_sandbox_file_t /app/polarity-web-modified

EOF
