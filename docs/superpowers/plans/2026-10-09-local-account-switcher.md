# Local Account Switcher Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. The user explicitly prohibited automatic commits; do not commit.

**Goal:** Build a local Windows GUI that saves legitimate desktop logins and switches them after the app fully exits, without touching chat data.

**Architecture:** A PowerShell 5.1 WinForms front end calls a small core module. The core encrypts auth.json with Windows DPAPI CurrentUser, validates the exact path and expected auth schema, and replaces only auth.json transactionally. The UI does not initiate a switch while ChatGPT or Codex processes are running.

**Tech Stack:** Windows PowerShell 5.1, .NET Framework WinForms, DPAPI, Pester 3.4.

---

## File map

- `AccountSwitcher.psm1`: credential validation, DPAPI, profile store, preflight, transaction, rollback.
- `Start-Switcher.ps1`: WinForms interface and user-facing error handling.
- `tests/AccountSwitcher.Tests.ps1`: fake-data tests for validation, DPAPI, enrollment, switching and rollback.
- `README.md`: setup, enrollment, safety limits and recovery.

### Task 1: Core validation and storage

- [ ] Write failing Pester tests for rejecting malformed auth JSON, invalid labels, path links, duplicate profiles, and DPAPI round-trip.
- [ ] Run `powershell -NoProfile -Command "Invoke-Pester .\tests\AccountSwitcher.Tests.ps1"`; confirm expected failures.
- [ ] Implement only the tested validation and encrypted store functions in `AccountSwitcher.psm1`.
- [ ] Run the same test command; confirm zero failures.

### Task 2: Transactional switch

- [ ] Write failing Pester tests with a fake `.codex/auth.json` for switch, source refresh, process guard, and rollback after a simulated write failure.
- [ ] Run tests; confirm expected failures.
- [ ] Implement transaction with temporary files and recovery backup, touching only `auth.json` and the tool's own store.
- [ ] Run tests; confirm zero failures.

### Task 3: GUI and operator guidance

- [ ] Write a static launch/import smoke test first; run it and confirm failure while script is absent.
- [ ] Implement WinForms label list, Save Current, Dry Run, Switch, and explanatory status. Require app closure before Switch; never force-kill.
- [ ] Add usage and rollback instructions to README.
- [ ] Run all tests, PowerShell parser checks, and a read-only dry run against installed app.

## Constraints

- Never read or print token values in diagnostic output.
- Never copy conversation, sqlite, or app package state.
- Never run a real account switch during this development chat.
- If installed app state cannot be identified safely, disable switch and report that limit.
