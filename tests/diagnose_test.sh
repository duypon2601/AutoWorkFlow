#!/bin/bash
# Test hồi quy cho phần chẩn đoán log agent của auto.sh (diagnose_agent_log, diag_advice ENV_HOOK,
# agent_env_fingerprint), câu nhắc skill cho agy (agy_skills_rule), câu nhắc tài liệu repo cho reviewer
# (plan_context_note, review_standards_note) và --install-skills (install_skills). Chạy: bash tests/diagnose_test.sh — exit ≠ 0 nếu có mục sai.
# Fixture env-hook-*/permission-* là log thật (đổi tên user); quota/crash/prose là log dựng tay.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
AUTO="$HERE/../auto.sh"
FIX="$HERE/fixtures"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Nạp biến DIAG_* và các hàm cần test từ auto.sh (không source cả file: nó chạy cả pipeline).
# auto.sh dùng CRLF → bỏ \r trước.
tr -d '\r' < "$AUTO" | awk '
  /^DIAG_[A-Z_]+=/ { print; next }
  /^skill_items\(\) \{.*\}$/ { print; next }
  /^(diag_tool_lines|diagnose_agent_log|diag_advice|agent_env_fingerprint|agy_skills_rule|plan_context_note|review_standards_note|install_skills)\(\) \{/ { infn = 1 }
  infn { print; if ($0 ~ /^}/) infn = 0 }
' > "$TMP/lib.sh"
# shellcheck source=/dev/null
. "$TMP/lib.sh"

fail=0; pass=0
ok()  { pass=$((pass + 1)); echo "  ✅ $1"; }
bad() { fail=$((fail + 1)); echo "  ❌ $1"; }

echo "diagnose_agent_log"
# fixture | exit code | nhãn mong đợi
while IFS='|' read -r fx rc want; do
  [ -n "$fx" ] || continue
  got=$(diagnose_agent_log "$FIX/$fx" "$rc")
  if [ "${got%%|*}" = "$want" ]; then ok "$fx → $want"
  else bad "$fx: mong đợi $want, nhận ${got%%|*} (bằng chứng: ${got#*|})"; fi
done <<'EOF'
env-hook-task6-try1.log|0|ENV_HOOK
env-hook-task6-try2.log|0|ENV_HOOK
env-hook-fatal-error-prose.log|0|ENV_HOOK
env-hook-preflight-probe.log|0|ENV_HOOK
permission-auto-denied.log|0|PERMISSION
quota-resource-exhausted.log|1|QUOTA
crash-traceback.log|1|CRASH
prose-no-error.log|0|NO_ACTION
EOF

echo "diag_advice ENV_HOOK"
AGY_PLUGINS_DIR="$TMP/plugins"; AGY_CONFIG="$TMP/config.json"
plugin=googlecloudtools.datacloud_telemetry
for fx in env-hook-task6-try1.log env-hook-task6-try2.log env-hook-fatal-error-prose.log; do
  adv=$(diag_advice ENV_HOOK "" "$FIX/$fx")
  if grep -qF "'$plugin'" <<< "$adv" && grep -qF "$AGY_PLUGINS_DIR/$plugin/hooks.json" <<< "$adv"; then ok "$fx → nêu đúng plugin $plugin"
  else bad "$fx: lời khuyên không nêu đúng plugin:"$'\n'"$adv"; fi
done
# Plugin có 2 thư mục (một bản đã đổi tên .disabled, agy vẫn nạp) → liệt kê hooks.json của cả hai, không khuyên mv
mkdir -p "$AGY_PLUGINS_DIR/$plugin" "$AGY_PLUGINS_DIR/$plugin.disabled" "$AGY_PLUGINS_DIR/other"
for d in "$plugin" "$plugin.disabled"; do printf '{\n  "name": "%s"\n}\n' "$plugin" > "$AGY_PLUGINS_DIR/$d/plugin.json"; done
printf '{ "name": "other" }\n' > "$AGY_PLUGINS_DIR/other/plugin.json"
adv=$(diag_advice ENV_HOOK "" "$FIX/env-hook-task6-try2.log")
if grep -qF "$AGY_PLUGINS_DIR/$plugin/hooks.json" <<< "$adv" && grep -qF "$AGY_PLUGINS_DIR/$plugin.disabled/hooks.json" <<< "$adv" \
   && ! grep -qF "other/hooks.json" <<< "$adv" && ! grep -q '^mv ' <<< "$adv"; then
  ok "plugin có bản .disabled → liệt kê hooks.json của mọi bản cùng tên"
else bad "plugin có bản .disabled:"$'\n'"$adv"; fi

echo "agent_env_fingerprint"
CODER=none; FALLBACK_CODER=""
printf '{"a":1}\n' > "$AGY_PLUGINS_DIR/$plugin/hooks.json"
fp1=$(agent_env_fingerprint)
printf '{"a":2}\n' > "$AGY_PLUGINS_DIR/$plugin/hooks.json"
fp2=$(agent_env_fingerprint)
printf '{"a":3}\n' > "$AGY_PLUGINS_DIR/$plugin.disabled/hooks.json"
fp3=$(agent_env_fingerprint)
mv "$AGY_PLUGINS_DIR/$plugin" "$AGY_PLUGINS_DIR/$plugin.disabled-1"
fp4=$(agent_env_fingerprint)
[ "$fp1" != "$fp2" ] && ok "đổi hooks.json → đổi fingerprint" || bad "đổi hooks.json không đổi fingerprint"
[ "$fp2" != "$fp3" ] && ok "đổi hooks.json trong thư mục *.disabled (agy vẫn nạp) → đổi fingerprint" || bad "bỏ sót thư mục *.disabled"
[ "$fp3" != "$fp4" ] && ok "đổi tên thư mục plugin → đổi fingerprint" || bad "đổi tên thư mục plugin không đổi fingerprint"

echo "agy_skills_rule"
if [ -z "$(AGY_SKILLS="" agy_skills_rule)" ]; then ok "AGY_SKILLS rỗng → không thêm gì vào prompt"
else bad "AGY_SKILLS rỗng mà vẫn thêm vào prompt"; fi
out=$(AGY_SKILLS="test-driven-development, debugging-and-error-recovery" agy_skills_rule)
case "$out" in
  *"/agent-skills:test-driven-development, /agent-skills:debugging-and-error-recovery."*) ok "liệt kê đủ skill, tách bằng phẩy hoặc dấu cách" ;;
  *) bad "thiếu skill trong câu nhắc: $out" ;;
esac
case "$out" in
  *"do not run git commit"*) ok "nhắc luật lệnh vẫn thắng skill (không commit)" ;;
  *) bad "không nhắc cấm commit: $out" ;;
esac

out=$(AGY_SKILLS="tdd" AGY_SKILLS_PLUGIN="mattpocock-skills" agy_skills_rule)
case "$out" in
  *"/mattpocock-skills:tdd."*) ok "AGY_SKILLS_PLUGIN đổi tiền tố skill" ;;
  *) bad "AGY_SKILLS_PLUGIN không được dùng: $out" ;;
esac

echo "plan_context_note / review_standards_note"
mkdir -p "$TMP/repo-empty" "$TMP/repo-docs/docs/adr" "$TMP/repo-docs/.scratch/login"
touch "$TMP/repo-docs/GLOSSARY.md" "$TMP/repo-docs/CONSTRAINTS.md" "$TMP/repo-docs/.scratch/login/spec.md"
if [ -z "$(cd "$TMP/repo-empty" && plan_context_note)" ] && [ -z "$(cd "$TMP/repo-empty" && review_standards_note)" ]; then
  ok "repo không có tài liệu → không thêm gì vào prompt"
else bad "repo không có tài liệu mà vẫn thêm câu nhắc"; fi
out=$(cd "$TMP/repo-docs" && plan_context_note)
case "$out" in
  "- Before writing"*"GLOSSARY.md, CONSTRAINTS.md, docs/adr, .scratch/*/spec.md.") ok "plan: liệt kê glossary, constraints, ADR, spec" ;;
  *) bad "plan_context_note sai: $out" ;;
esac
out=$(cd "$TMP/repo-docs" && review_standards_note)
case "$out" in
  *"Read CONSTRAINTS.md, GLOSSARY.md from the working tree"*"blocking"*) ok "review: liệt kê file chuẩn cho trục Standards" ;;
  *) bad "review_standards_note sai: $out" ;;
esac

echo "install_skills"
mkdir -p "$TMP/src/alpha" "$TMP/src/beta/agents" "$TMP/src/not-a-skill" "$TMP/dest/beta"
echo a > "$TMP/src/alpha/SKILL.md"; echo b > "$TMP/src/beta/SKILL.md"; echo y > "$TMP/src/beta/agents/x.yaml"
echo mine > "$TMP/dest/beta/SKILL.md"
install_skills "$TMP/src" "$TMP/dest" > "$TMP/install.log"
if [ -f "$TMP/dest/alpha/SKILL.md" ]; then ok "chép skill mới"; else bad "không chép alpha"; fi
if [ "$(cat "$TMP/dest/beta/SKILL.md")" = mine ]; then ok "skill đã có ở đích được giữ nguyên"; else bad "ghi đè skill đã có"; fi
if [ ! -e "$TMP/dest/not-a-skill" ]; then ok "bỏ qua thư mục không có SKILL.md"; else bad "chép thư mục không phải skill"; fi
if grep -qF "Đã chép 1 skill" "$TMP/install.log"; then ok "báo đúng số skill đã chép"; else bad "báo sai: $(cat "$TMP/install.log")"; fi

echo "Kết quả: $pass đạt, $fail sai"
[ "$fail" -eq 0 ]
