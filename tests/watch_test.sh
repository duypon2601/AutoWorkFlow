#!/bin/bash
# Test AGY_WATCH (auto.sh): giả lập một hội thoại agy (SQLite, cùng dạng bảng steps) được ghi dần trong lúc
# watcher chạy, kiểm tra các bước được in ra đúng lúc, lỗi được báo, không in trùng. Không gọi agy thật.
# Chạy: bash tests/watch_test.sh — exit ≠ 0 nếu có mục sai.
set -uo pipefail
export LC_ALL=C  # grep của Git Bash không khớp được emoji 4 byte ở locale UTF-8 → so theo byte

HERE="$(cd "$(dirname "$0")" && pwd)"
AUTO="$HERE/../auto.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Nạp AGY_WATCH_PY, py_paths, agy_watch_start/stop và cách chọn PY từ auto.sh (bỏ \r: file dùng CRLF)
tr -d '\r' < "$AUTO" | awk '
  /^AGY_WATCH_PY=\x27/ { inpy = 1 }
  inpy { print; if ($0 == "\x27") inpy = 0; next }
  /^PY=""$/ || /^for p in python3 python; do/ || /^py_paths\(\)/ { print; next }
  /^(agy_watch_start|agy_watch_stop)\(\) \{/ { infn = 1 }
  infn { print; if ($0 ~ /^}/) infn = 0 }
' > "$TMP/lib.sh"
# shellcheck source=/dev/null
. "$TMP/lib.sh"
if [ -z "$PY" ]; then echo "⚠️  Không có Python có sqlite3 — bỏ qua test AGY_WATCH"; exit 0; fi

fail=0; pass=0
ok()  { pass=$((pass + 1)); echo "  ✅ $1"; }
bad() { fail=$((fail + 1)); echo "  ❌ $1"; }

mkdir -p "$TMP/conv" "$TMP/repo/.auto-logs"
cd "$TMP/repo" || exit 1
REPO_PY=$("$PY" -c 'import os; print(os.getcwd().replace("\\", "/"))')
LOG_DIR=.auto-logs; AGY_WATCH=1; AGY_CONV_DIR="$TMP/conv"
DB=$(printf '%s\n' "$TMP/conv/c0ffee.db" | py_paths)

# writer <lệnh> — thêm/cập nhật bước trong DB giả (payload giống agy: call_N <tool> {json})
writer() {
  "$PY" - "$DB" "$REPO_PY" "$@" <<'EOF'
import json, sqlite3, sys
db, repo, op = sys.argv[1], sys.argv[2], sys.argv[3]
con = sqlite3.connect(db)
con.execute("pragma journal_mode=wal")
con.execute("create table if not exists steps (idx integer primary key, step_type integer, status integer, step_payload blob, error_details blob)")
def call(idx, tool, args, status=1):
    payload = b"\n\x04\x08\x01\x12\x00\"\x0ccall_" + str(600 + idx).encode() + b"\x12\x0b" + tool.encode() + b"\x1a" + json.dumps(args).encode() + b":\x02\x10\x01"
    con.execute("insert into steps values (?, 132, ?, ?, NULL)", (idx, status, payload))
if op == "start":
    con.execute("insert into steps values (0, 14, 3, ?, NULL)", (b"user prompt",))
    call(1, "view_file", {"AbsolutePath": repo + "/src/app.py", "StartLine": 1, "EndLine": 40, "toolSummary": "View app.py"}, 3)
elif op == "more":
    con.execute("insert into steps values (2, 15, 3, ?, NULL)", (b"model text",))
    call(3, "run_command", {"CommandLine": "make test", "Cwd": repo, "toolSummary": "Run tests"})
elif op == "finish":
    con.execute("update steps set status = 3 where idx = 3")
    call(4, "replace_file_content", {"TargetFile": repo + "/src/app.py", "Description": "Fix off-by-one"}, 3)
    call(5, "write_to_file", {"TargetFile": repo + "/tests/test_app.py", "toolSummary": "Add test"}, 7)
    con.execute("update steps set error_details = ? where idx = 5", (b"\x0a\x20JSON hook \"jsonhook__x_PreToolUse_0_0\" failed: exit status 1",))
con.commit()
EOF
}

LOG="$TMP/repo/.auto-logs/task1-try1-code.log"
agy_watch_start "$LOG" > "$TMP/screen.txt"
[ -n "$AGY_WATCH_PID" ] && ok "watcher chạy nền" || bad "watcher không chạy"
sleep 1; writer start
sleep 3
early=$(cat "$TMP/screen.txt")
writer more; sleep 3; writer finish
agy_watch_stop
screen=$(cat "$TMP/screen.txt")

grep -qF "👀 src/app.py (dòng 1-40)" <<< "$early" && ok "in bước đầu ngay khi agy còn chạy" || bad "chưa in bước đầu khi đang chạy: $early"
grep -qF '$ make test' <<< "$screen" && ok "in lệnh agy chạy" || bad "thiếu lệnh: $screen"
grep -qF "✏️ src/app.py — Fix off-by-one" <<< "$screen" && ok "in file agy sửa (đường dẫn tương đối)" || bad "thiếu bước sửa file: $screen"
grep -qF "✏️ tests/test_app.py — Add test" <<< "$screen" && ok "in file agy ghi" || bad "thiếu bước ghi file: $screen"
grep -qE "❌ lỗi: .*jsonhook__x_PreToolUse_0_0" <<< "$screen" && ok "báo lỗi của bước (error_details)" || bad "thiếu dòng lỗi: $screen"
[ "$(grep -cF '$ make test' <<< "$screen")" -eq 1 ] && ok "không in trùng khi trạng thái bước đổi" || bad "in trùng: $screen"
! grep -qE "user prompt|model text" <<< "$screen" && ok "chỉ in bước gọi công cụ" || bad "in cả bước không phải công cụ"
[ "$(grep -c . "$LOG.steps" 2>/dev/null)" -eq "$(grep -c . <<< "$screen")" ] && ok "ghi cùng nội dung vào <log>.steps" || bad "<log>.steps khác màn hình"
[ -z "$AGY_WATCH_PID" ] && [ ! -e "$LOG_DIR/.watch-stop" ] && ok "dừng watcher và dọn file cờ" || bad "watcher chưa dừng sạch"

echo "Màn hình giả lập:"; sed 's/^/  │/' <<< "$screen"
echo "Kết quả: $pass đạt, $fail sai"
[ "$fail" -eq 0 ]
