# Skill cho autowf

22 skill cho Claude Code khi làm việc với một repo chạy bằng autowf. 21 skill lấy từ
[mattpocock/skills](https://github.com/mattpocock/skills) (commit `5beb35b`, 2026-10-19, giấy phép MIT:
[LICENSE-mattpocock](LICENSE-mattpocock)), 1 skill viết mới (`to-autowf-plan`).

Cài vào một dự án: chạy `autowf --install-skills` ở gốc repo đó. Lệnh chép từng thư mục skill vào
`.claude/skills/`, giữ nguyên skill đã có. Sau đó commit `.claude/skills/` rồi chạy `/setup-matt-pocock-skills`
một lần (chọn tracker "Local markdown").

## Quy trình

1. **Trước khi chạy** (Claude Code, có hỏi đáp): `/grill-with-docs` → `/to-spec` → `/to-autowf-plan`.
   Việc quá lớn cho một PLAN.md: `/wayfinder` trước.
2. **Chạy** `autowf` trong terminal. Skill không chạy trong pipeline; auto.sh chỉ mượn ý tưởng (xem dưới).
3. **Sau khi chạy**: `/retro` (đọc `.auto-logs/`), `/pr`, thỉnh thoảng `/improve-codebase-architecture`.

## Danh sách

| Skill | Dùng khi | Chỉnh so với bản gốc |
| --- | --- | --- |
| `grill-with-docs` | Phỏng vấn kỹ yêu cầu, ghi glossary/ADR | |
| `grilling` | "grill me" một ý tưởng | |
| `domain-modeling` | Thuật ngữ, GLOSSARY.md, ADR | |
| `to-spec` | Tổng hợp cuộc trò chuyện thành spec | Nhắc bước tiếp `/to-autowf-plan` |
| `to-autowf-plan` | Spec → PLAN.md cho autowf | Mới, viết lại từ `to-tickets` |
| `wayfinder` | Việc nhiều phiên, cần bản đồ quyết định | Thêm mục bàn giao sang autowf |
| `setup-matt-pocock-skills` | Cấu hình repo một lần | Khuyên tracker local, thêm mục autowf vào CLAUDE.md |
| `prototype` | Thử nhanh UI/logic trước khi khoá plan | |
| `research` | Tra docs/API ra file Markdown | |
| `codebase-design` | Thiết kế interface, deep module | |
| `improve-codebase-architecture` | Dọn kiến trúc định kỳ | |
| `wizard` | Bước chỉ người làm được (đăng nhập, secret) | |
| `to-questionnaire` | Autowf dừng vì plan-gap, cần người quyết | |
| `code-review` | Review branch `auto/*` thủ công | auto.sh mượn 2 trục Spec + Standards |
| `tdd` | Viết test trước | Dùng cho agy qua `AGY_SKILLS_PLUGIN` nếu agy cài được |
| `diagnosing-bugs` | Autowf dừng bất thường, bug khó | |
| `retro` | Rút kinh nghiệm sau một lần chạy | Đọc `.auto-logs/`, `CONSTRAINTS.md` |
| `pr` | Viết mô tả PR | |
| `handoff` | Bàn giao sang phiên Claude mới | |
| `writing-for-agents` | Sửa skill, CLAUDE.md, AGENTS.md | |
| `git-guardrails-claude-code` | Chặn Claude chạy lệnh git nguy hiểm | |
| `wait-what` | Câu trả lời khó hiểu | |

16 skill còn lại của repo gốc không lấy: trùng bộ agent-skills đang dùng, bắt Claude tự viết code hoặc điều
phối sub-agent (tốn token, ngược mục tiêu của autowf), hoặc không liên quan tới code.

## auto.sh mượn gì

- Prompt viết plan: đọc `GLOSSARY.md`, `CONSTRAINTS.md`, `docs/adr/`, `.scratch/*/spec.md` nếu có; chia task theo
  lát cắt dọc; quyết định sẵn mọi chi tiết để không bị plan-gap.
- Review: hai trục Spec (tiêu chí của task) và Standards (`CONSTRAINTS.md`, `CODING_STANDARDS.md`, `GLOSSARY.md`
  nếu có). Vẫn một lần gọi reviewer, không sub-agent.
- `AGY_SKILLS_PLUGIN`: đổi plugin mà `AGY_SKILLS` trỏ tới (mặc định `agent-skills`).

Cập nhật từ bản gốc: so commit ghi ở trên với repo của Matt, chép lại thư mục cần cập nhật, rồi áp lại các chỉnh
trong bảng.
