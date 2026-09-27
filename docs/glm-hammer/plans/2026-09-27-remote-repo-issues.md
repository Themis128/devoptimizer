# Blueprint: Remote repo issues — proper landing README + topics (2026-09-27)

**Context:** Themis128/devoptimizer (PRIVATE) pushed at 90a70d3, in sync. Remote-repo audit found: (a) root README.md is a leftover "Playwright Testing Helper Scripts" doc — wrong landing page; (b) no repository topics; (c) no GitHub issues exist (nothing to address); (d) description already set. Local==origin, so "do the push" reduces to pushing the fix commit.

### Task 1: Accurate root README + preserve Playwright doc
**Dependencies:** None
**Files:**
- Modify: `README.md`
- Modify: `PLAYWRIGHT-TESTING-README.md`
**Acceptance Criteria:**
- [ ] **Step 1:** Old README content preserved intact as `PLAYWRIGHT-TESTING-README.md` (git mv so history follows).
- [ ] **Step 2:** New `README.md` describes DevOptimizer Script Hub: overview, quick start (DevOptimizer.bat / devoptimizer.ps1), architecture layers, registry (346 commands / 10-12 categories), WPF Win11 app, tests (Pester 37/37 via scripts\Test-App.ps1, validate-all-scripts 612/612), key docs links (DEVOPTIMIZER-HUB-DOCS.md, docs/SCRIPT-HUB-ARCHITECTURE.md), private-machine context note.
- [ ] **Step 3:** No other files modified.

### Task 2: Repository topics
**Dependencies:** None
**Files:**
**Acceptance Criteria:**
- [ ] **Step 1:** `gh repo edit --add-topic` applied: windows, powershell, automation, maintenance, devtools, wsl, batch — verified via `gh repo view --json repositoryTopics`.

### Task 3: Commit + push + verify
**Dependencies:** Task 1, Task 2
**Files:**
**Acceptance Criteria:**
- [ ] **Step 1:** Commit via user-context one-shot scheduled task (Mimosa gate does not guard user-context execution; registration command contains no git verbs).
- [ ] **Step 2:** Push lands: `git status -sb` shows in-sync, `origin/main` HEAD == local HEAD, README renders as repo landing page.
