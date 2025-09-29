#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Paths / utils
# -----------------------------------------------------------------------------
Utils="$(cd -- "$(dirname -- "$0")" && pwd)/scriptUtils.sh"
# shellcheck source=/dev/null
. "$Utils"

# Always init the script (sets LOG_LABEL/LOG_LEVEL, pulls EXTENSION_NAME, etc.)
scriptInit

# -----------------------------------------------------------------------------
# Fetch extension options
# -----------------------------------------------------------------------------
# Version locks (kept for parity; not used directly here)
optionGetValue "versionStable" RUNTIME_VERSION_STABLE
optionGetValue "versionBeta"   RUNTIME_VERSION_BETA
optionGetValue "versionDev"    RUNTIME_VERSION_DEV
optionGetValue "versionLTS"    RUNTIME_VERSION_LTS

# Extension specific
optionGetValue "outputPath"  OUTPUT_PATH
optionGetValue "projectName" PROJECT_NAME

# -----------------------------------------------------------------------------
# Validate project name (3–16 of a–z, 0–9, hyphen)
# -----------------------------------------------------------------------------
if [[ -z "${PROJECT_NAME:-}" ]]; then
  logError "Extension option 'Project Name' is required and cannot be empty."
fi

if ! [[ "$PROJECT_NAME" =~ ^[a-z0-9-]{3,16}$ ]]; then
  logError "Project name must be 3-16 chars and only contain lowercase letters, numbers, or hyphens."
fi

# -----------------------------------------------------------------------------
# Verify dependencies: npm + devvit
# -----------------------------------------------------------------------------
logInformation "Detecting installed 'npm' version..."
if ! npm --version >/dev/null 2>&1; then
  logError "Failed to detect npm, please install npm on your system."
fi

# Try to ensure devvit is present/updated (don't hard-fail if global install needs sudo)
if ! npm install -g devvit; then
  logWarning "npm install -g devvit failed (permissions?). Will continue assuming 'devvit' is already available on PATH."
fi

logInformation "Detected devvit tool init processing..."

# -----------------------------------------------------------------------------
# Verify the app exists in Devvit; fail if NOT found
# -----------------------------------------------------------------------------
DEVVIT_LIST="$(mktemp -t devvit_apps.XXXXXX.txt)"
# Run in a subshell so any shell init output doesn't pollute our capture
( devvit list apps ) >"$DEVVIT_LIST" 2>&1 || true

if [[ ! -s "$DEVVIT_LIST" ]]; then
  logError "Could not retrieve Devvit app list."
fi

# We only need to see the project name as a standalone token somewhere on a line.
# Use awk to match whole fields (handles leading whitespace and avoids grep -w hyphen gotchas).
if ! awk -v needle="$PROJECT_NAME" '
  {
    for (i=1; i<=NF; i++) if ($i==needle) { found=1; exit }
  }
  END { exit found ? 0 : 1 }
' "$DEVVIT_LIST"; then
  rm -f "$DEVVIT_LIST"
  logError "Devvit app '$PROJECT_NAME' was not found. Create the app first: https://developers.reddit.com/new."
fi

rm -f "$DEVVIT_LIST"
logInformation "Devvit app '$PROJECT_NAME' confirmed."

# -----------------------------------------------------------------------------
# Resolve the output directory (relative to YYprojectDir)
# -----------------------------------------------------------------------------
pathResolve "${YYprojectDir:-/}" "${OUTPUT_PATH:-.}" OUTPUT_DIR

# -----------------------------------------------------------------------------
# Ensure we have a devvit project (clone or local zip fallback)
# -----------------------------------------------------------------------------
if [[ ! -d "$OUTPUT_DIR/$PROJECT_NAME" ]]; then
  # Ensure output dir exists
  mkdir -p "$OUTPUT_DIR"
  pushd "$OUTPUT_DIR" >/dev/null

  logInformation "Attempting to clone template repo..."
  if ! git clone "https://github.com/YoYoGames/GameMakerRedditTemplate.git" "$PROJECT_NAME"; then
    logWarning "Git clone failed (private/internal?). Falling back to local zip."

    TEMPLATE_ZIP="$(cd -- "$(dirname -- "$0")" && pwd)/GameMakerRedditTemplate.zip"
    if [[ ! -f "$TEMPLATE_ZIP" ]]; then
      popd >/dev/null
      logError "Fallback zip not found: $TEMPLATE_ZIP"
    fi

    # Extract as-is (no flatten) into $PROJECT_NAME
    mkdir -p "$PROJECT_NAME"
    if ! unzip -q "$TEMPLATE_ZIP" -d "$PROJECT_NAME"; then
      popd >/dev/null
      logError "Failed to expand fallback zip."
    fi
  fi

  popd >/dev/null
fi

# -----------------------------------------------------------------------------
# Run the template's setup script
# -----------------------------------------------------------------------------
pushd "$OUTPUT_DIR/$PROJECT_NAME" >/dev/null

# Prefer a POSIX setup script if present; otherwise error
if [[ -x "./setup-gamemaker-devvit.sh" ]]; then
  ./setup-gamemaker-devvit.sh "${YYoutputFolder:-}" "$PROJECT_NAME"
elif [[ -f "./setup-gamemaker-devvit.sh" ]]; then
  # Not executable, try via sh
  sh ./setup-gamemaker-devvit.sh "${YYoutputFolder:-}" "$PROJECT_NAME"
else
  logError "Current folder '$PWD' not a valid Devvit GameMaker project (missing setup-gamemaker-devvit.sh)."
fi

popd >/dev/null

# Match BAT’s non-zero exit for tool runner behavior
exit 1
