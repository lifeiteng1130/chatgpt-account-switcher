# Account cards and email display — design

## Goal

Make the existing Windows account switcher easier to recognize and use. Saved accounts display as `email · remark` when the current account's email can be read locally; otherwise they retain the existing label-only display. No re-login is required for existing saved accounts.

## Data source and compatibility

- Read the `email` claim from the existing `id_token` in `auth.json` at enrollment; do not transmit the token or call a network API.
- Decode only the JWT payload and validate the email shape. Do not log or display raw token content.
- Account identity remains the existing `account_id`, not the email. The email is display metadata, never used to authorize a switch.
- If an email is absent, malformed, or no longer available after an app update, save and display the existing label alone.
- Existing encrypted `.profile` files remain valid. Optional display metadata is stored separately under the switcher's local store; old profiles appear by label until explicitly updated.

## UI

- Replace the compact two-combo-box form with a wider card/list layout showing each saved account's display name, current/target state, and short safety guidance.
- Enrollment asks for a remark. When email is available, display `email · remark`; otherwise use the entered remark as the label.
- The app shows the detected current account without putting tokens or account IDs on screen. It disables switching while relevant app processes run.
- Keep Save Current, Preflight, and Switch actions; switching still requires confirmation and manual relaunch/verification of the official app.

## Safety and tests

- Do not change the existing encrypted credential profile format, switch transaction, or local conversation files.
- Do not put email in a profile filename or in logs; treat metadata as local personal information.
- Add fake-token tests for email present, missing, and malformed, plus existing-profile compatibility and display formatting.
- Verify PowerShell 5.1 syntax and UI startup without switching a real account.

## Limitations

The JWT claim is a local implementation detail, not a permanent public contract. If it disappears, the tool falls back to the current label behavior. This update does not add concurrent accounts or automatic post-switch verification.
