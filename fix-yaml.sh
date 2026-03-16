#!/usr/bin/env bash
set -euo pipefail

echo "Fixing YAML files..."

YAML_TARGETS=(roles playbooks inventory .)

for dir in "${YAML_TARGETS[@]}"; do
  [ -e "$dir" ] || continue

  if [ -d "$dir" ]; then
    find "$dir" -type f \( -name "*.yml" -o -name "*.yaml" -o -name ".yamllint" \) -print0
  elif [ -f "$dir" ] && [ "$(basename "$dir")" = ".yamllint" ]; then
    printf '%s\0' "$dir"
  fi
done | while IFS= read -r -d '' file; do
  echo "Processing $file"

  # Remove trailing spaces/tabs
  sed -i 's/[[:space:]]*$//' "$file"

  # Remove blank lines at end of file, keep exactly one newline
  perl -0pi -e 's/\n+\z/\n/' "$file"

  # Ensure file ends with exactly one newline
  python3 - <<'PY' "$file"
from pathlib import Path
import sys

p = Path(sys.argv[1])
data = p.read_bytes()
data = data.rstrip(b"\n") + b"\n"
p.write_bytes(data)
PY

  # Safe permissions for YAML files
  case "$(basename "$file")" in
    .yamllint|*.yml|*.yaml)
      chmod 644 "$file"
      chmod -x "$file"
      ;;
  esac
done

echo "Fixing script and directory permissions..."

if [ -d roles ]; then
  find roles -type f -name "*.sh" -exec chmod 755 {} +
  find roles -type d -exec chmod 755 {} +
fi

# Drop ACLs if setfacl exists
if command -v setfacl >/dev/null 2>&1; then
  setfacl -b roles/* playbooks/* inventory/* 2>/dev/null || true
fi

# Remove executable bit from all non-shell files
for dir in roles playbooks inventory; do
  [ -d "$dir" ] || continue
  find "$dir" -type f ! -name "*.sh" -exec chmod a-x {} +
done

echo "Checking for risky permissions..."
for dir in roles playbooks inventory; do
  [ -d "$dir" ] || continue
  find "$dir" -type f -perm /022 -ls || true
done

echo "Done."
