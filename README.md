# Jira Sprint Tracker

A native macOS menu bar app that tracks your active Jira sprint tasks across up to three project/board pairs, with an optional small priority-summary widget.

## Install (Homebrew)

```bash
brew tap mildminihi/jira-sprint-tracker
brew trust mildminihi/jira-sprint-tracker
brew install --cask jira-sprint-tracker
```

Upgrade later:

```bash
brew update
brew upgrade --cask jira-sprint-tracker
```

After install, open **Jira Sprint Tracker** from Applications (or Spotlight). A checklist icon appears in the menu bar with a live summary like `3d · 5`.

### Configure Jira

1. Click the menu bar icon → **Settings**, or press **Cmd+,**
2. Create an [Atlassian API token](https://id.atlassian.com/manage-profile/security/api-tokens)
3. Paste your board URL into **Quick add from board link**, or enter fields manually
4. Click **Test Connection** → **Save**
5. Optionally enable **Open at Login**

**Board link example:**

```
https://your-domain.atlassian.net/jira/software/c/projects/LM/boards/99
```

Each person uses their own API token. Credentials stay on the local machine in the App Group  
`group.supanat.wanroj.jira-tracker-widget`.

## Features

- Menu bar summary: nearest sprint days left + non-Done count (`3d · 5`), tinted when urgent
- Popover scope: **This board** / **All** (remembered), with board picker
- Filters: **All / Active / In Progress** chips (default Active) + search by key/summary
- Compact mode for denser cards
- Open sprint / Open board links (board link hidden in All mode)
- Copy issue URL from each task card
- Settings: Open at Login, last refresh health, persisted Test Connection results
- Optional **systemSmall** desktop widget: priority counts for non-Done tasks (same board scope as the app)
- Refreshes about every 30 minutes, on manual refresh, and in the background

## Optional widget

1. Right-click the desktop → **Edit Widgets**
2. Search for **Jira Priority Summary**
3. Add the small widget

## Requirements

- macOS 14 (Sonoma) or later
- Atlassian Cloud account with permission to read boards, sprints, and issues

## Develop from source

Prerequisites: Xcode 15+, an Apple ID signing team (Personal Team is fine for local runs).

```bash
git clone https://github.com/mildminihi/jira-tracker-widget.git
cd jira-tracker-widget
open jira-tracker-widget.xcodeproj
```

1. Select **jira-tracker-widget** and **jira-tracker-widget-extension** → **Signing & Capabilities**
2. Choose your **Team** and enable **Automatically manage signing**
3. Confirm App Group on both targets: `group.supanat.wanroj.jira-tracker-widget`
4. Run the **jira-tracker-widget** scheme (Cmd+R)

Unit tests (no Jira credentials required):

```bash
xcodebuild test -scheme jira-tracker-widget -destination 'platform=macOS' -only-testing:jira-tracker-widgetTests
```

**Signing notes**

| Audience | What you need |
|---|---|
| Local develop / debug | Any Apple ID team + automatic signing |
| Distribute via Homebrew / share outside your Mac | Apple Developer Program + **Developer ID Application** + notarization ([docs/RELEASE.md](docs/RELEASE.md)) |

Released builds are signed with Developer ID team `3D465Z2MU3` (maintainer). Your local Team ID will differ; that is expected.

## Project structure

```
jira-tracker-widget/
├── jira-tracker-widget/            Menu bar app + Settings
├── jira-tracker-widget-extension/  Small priority summary widget
├── Shared/                         Models, API client, UI, storage
├── docs/                           Release guide (+ archive/ old plans)
└── scripts/                        Release / notarize helpers
```

## Releasing

Maintainers: see [docs/RELEASE.md](docs/RELEASE.md) for Developer ID signing, notarization, GitHub Releases, and updating the Homebrew cask.

## Troubleshooting

| Message | Fix |
|---|---|
| Open Jira Sprint Tracker to configure | Open Settings (Cmd+,) and save credentials |
| Authentication failed | Check email and API token |
| Board ID invalid for project X | Verify the board ID from the Jira board URL |
| No tasks assigned to you in open sprints | Confirm you have issues in an active sprint |
| No open sprints on the configured board | Check that the board has an active/future sprint |
| Unable to reach Jira | Check network/VPN and Jira domain URL |
| App blocked on first open | Prefer the notarized Homebrew build; otherwise Right-click → Open once |

## API usage

- `GET /rest/api/3/myself` — auth check
- `GET /rest/agile/1.0/board/{boardId}/sprint` — open sprints
- `GET /rest/agile/1.0/sprint/{sprintId}/issue` — tasks per sprint

## License

MIT — see [LICENSE](LICENSE).
