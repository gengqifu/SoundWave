#!/usr/bin/env bash
set -euo pipefail

# 故意制造格式化失败，用于验证 CI 格式检查是否能挡住。
# 创建临时未格式化文件并运行 dart format --set-exit-if-changed。

TMP_FILE="$(mktemp /tmp/soundwave_format_fail_XXXX.dart)"
cat > "$TMP_FILE" <<'EOF'
void main(){print("unformatted");}
EOF

echo "Created unformatted file: $TMP_FILE"
echo "Running dart format (expect failure)..."
if dart format --output=none --set-exit-if-changed "$TMP_FILE"; then
  echo "Unexpected success; format check did not fail."
  rm "$TMP_FILE"
  exit 1
else
  echo "Format check failed as expected."
  rm "$TMP_FILE"
fi
