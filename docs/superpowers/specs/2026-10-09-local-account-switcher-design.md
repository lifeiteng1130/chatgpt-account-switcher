# Windows ChatGPT local account switcher — design

## Goal

Provide a small Windows GUI for manually switching between locally saved ChatGPT desktop accounts without completing browser login on every switch. Each account must be signed in legitimately at least once. Switching may close and restart the desktop app.

## Scope

- Only the current Windows user and the official `OpenAI.Codex`/ChatGPT desktop app.
- Manual account registration and switching; no automatic rotation, remote API, quota monitoring, or credential export.
- Preserve existing local chats, projects, plugins, skills, settings, and session databases.
- Do not bypass account access controls or promise that an expired/revoked login can be reused.

## Architecture

A local GUI coordinates an account store, an app-state adapter, and a switch transaction. Credentials are encrypted with Windows DPAPI CurrentUser before being saved. Non-secret account labels and metadata are stored separately. The adapter discovers supported app paths and versions; it uses an explicit allowlist of account-specific state files, never a recursive copy of `.codex` or the MSIX package directory. If the current build's account state cannot be identified safely, switching is disabled with a clear diagnostic.

## Account enrollment

1. Detect and display the active account without printing tokens.
2. Save the current legitimate login under a user-chosen label.
3. The user signs in to each additional account through the official app once, then saves it under another label.
4. Validate saved data and encrypt the credential payload. The UI never displays or logs token values.

## Switch transaction

1. Show source and target labels and require confirmation.
2. Refuse to switch while the official app or Codex helpers have an active task, or when required state is unknown.
3. Close the official desktop app gracefully; verify all targeted processes have stopped. Never force-kill an unrelated `ChatGPT.exe`.
4. Save the departing account's refreshed account-specific state, create a recoverable backup of live state, and atomically activate the target's saved state.
5. Relaunch the official app and verify the displayed account identity and ability to load Chat/Work/Codex account metadata. If verification fails, close the app, restore the backup, and relaunch the original account.
6. The switcher never touches local conversation databases or session files.

## Security and errors

- Encrypted profile files are bound to the current Windows user. They are not portable backups.
- The live app's credential file may remain plaintext because the official app requires that format; treat it as a password.
- Reject symlinks/junctions and paths outside the expected user profile. Use per-user filesystem permissions and atomic file replacement.
- Reject duplicate labels, corrupt/expired profiles, unexpected app versions, and ambiguous process discovery with actionable messages.
- Logs contain timestamps, operation stages, and error codes but no tokens, raw auth JSON, email addresses, or conversation contents.
- Do not run a real switch while the development chat is active.

## Verification

- Unit tests with fake account payloads for encryption, validation, enrollment, switching, rollback, path guards, and process failures.
- Read-only compatibility inspection of the installed Windows app before enabling real switching.
- A dry-run mode reports exactly which paths and processes would be involved without reading token values into output or changing state.
- Real two-account end-to-end verification is deferred until the user can close this chat and explicitly initiates it.

## Non-goals and caveats

The tool does not run two accounts concurrently, merge cloud conversations, or share one account's server-side history with another. Future desktop app updates can change private state locations; fail closed until the adapter is updated.
