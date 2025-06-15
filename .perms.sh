#!/usr/bin/env bash
set -euo pipefail

# === fix.perms.sh ===
# Ensures secure, consistent permissions across the repo

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT_DIR}"

echo "🔧 Fixing permissions under ${ROOT_DIR}..."

# 1. Make all shell scripts executable
echo "📜 Making all .sh files executable (755)..."
find . -type f -name "*.sh" -exec chmod 755 {} +

# 2. Ensure non-shell files (README, .json, .md, etc) are readable only
echo "📘 Setting 644 for all other non-binary files..."
find . -type f ! -name "*.sh" ! -name "*.sqlite" ! -name "*.db" -exec chmod 644 {} +

# 3. Make .env readable (if exists)
if [[ -f .env ]]; then
  echo "📄 Adjusting .env permissions..."
  chmod 644 .env
fi

# 4. Strip world-writable files (for security)
echo "🔒 Removing world-writable bits (chmod o-w)..."
find . -type f -perm -0002 -exec chmod o-w {} +

# 5. Set execution for core scripts in root (even if no .sh suffix)
for core in organize_audiobooks fix.perms run_all_tests; do
  if [[ -f "${core}" || -f "${core}.sh" ]]; then
    chmod 755 "${core}"* 2>/dev/null || true
  fi
done

# 6. Optional: Recursively fix folder permissions to 755
echo "📁 Ensuring all directories are executable..."
find . -type d -exec chmod 755 {} +

# 7. Optional: Output summary
echo "✅ Permissions reset complete."
echo "🧪 Suggest running ./run_all_tests.sh or ./organize_audiobooks.sh --dry-run to verify."

###EOF
