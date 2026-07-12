# Jira Sprint Tracker

A native macOS menu bar app that tracks your active Jira sprint tasks across up to three project/board pairs.

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

After install, open **Jira Sprint Tracker** from Applications (or Spotlight). A checklist icon appears in the menu bar.

### Configure Jira

1. Click the menu bar icon → **Settings**, or press **Cmd+,**
2. Create an [Atlassian API token](https://id.atlassian.com/manage-profile/security/api-tokens)
3. Paste your board URL into **Quick add from board link**, or enter fields manually
4. Click **Test Connection** → **Save**

**Board link example:**

```
https://your-domain.atlassian.net/jira/software/c/projects/LM/boards/99
```

Each person uses their own API token. Credentials stay on the local machine in the App Group  
`group.supanat.wanroj.jira-tracker-widget`.

## Features

- Menu bar icon with a scrollable popover of sprint tasks
- Up to 3 project + board pairs
- Paste a Jira board URL to auto-fill project key and board ID
- Tasks grouped by sprint and status, with progress bar and countdown
- Click a task to open it in Jira; use the link button to copy its URL
- Refreshes every 30 minutes, on manual refresh, and when the app becomes active

## Requirements

- macOS 14 (Sonoma) or later
- Atlassian Cloud account with permission to read boards, sprints, and issues

## Develop from source

Prerequisites: Xcode 15+, Apple signing team (personal ID is fine for local runs).

```bash
git clone https://github.com/mildminihi/jira-tracker-widget.git
cd jira-tracker-widget
open jira-tracker-widget.xcodeproj
```

1. Select the **jira-tracker-widget** target → **Signing & Capabilities**
2. Choose your **Team** and enable **Automatically manage signing**
3. Confirm App Group: `group.supanat.wanroj.jira-tracker-widget`
4. Run the **jira-tracker-widget** scheme (Cmd+R)

## Project structure

```
jira-tracker-widget/
├── jira-tracker-widget/   Menu bar app + Settings
├── Shared/                Models, API client, UI, storage
└── scripts/               Release / notarize helpers
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
