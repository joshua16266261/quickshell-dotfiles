# Calendar Setup (khal + vdirsyncer + Quickshell)

## 1. Rebuild
sudo nixos-rebuild switch --flake ~/dotfiles/nixos-dotfiles
systemctl --user daemon-reload
systemctl --user enable --now vdirsyncer-sync.timer

## 2. Google OAuth (one-time, free)
1. Go to https://console.cloud.google.com → New Project (e.g. `quickshell-calendar`)
2. Enable APIs: search `CalDAV` and `CardDAV` → Enable (NOT Calendar API)
3. OAuth consent screen → External → Fill app name/support email → **Publishing status → Publish → In production** (stays unverified, OK for 1 user — avoids 7-day expiry)
4. Credentials → Create Credentials → OAuth Client ID → Desktop Application → copy Client ID + Client Secret

## 3. Configure vdirsyncer
mkdir -p ~/.config/vdirsyncer ~/.calendars ~/.vdirsyncer
cat > ~/.config/vdirsyncer/config <<EOF
[general]
status_path = "~/.calendars/status"

[pair google_sync]
a = "google_cal"
b = "local_cal"
collections = [["from a", "from b"]]
conflict_resolution = "a wins"
metadata = ["color", "displayname"]

[storage google_cal]
type = "google_calendar"
token_file = "~/.vdirsyncer/google_token"
client_id = "YOUR_CLIENT_ID"
client_secret = "YOUR_CLIENT_SECRET"

[storage local_cal]
type = "filesystem"
path = "~/.calendars/"
fileext = ".ics"
EOF
chmod 600 ~/.config/vdirsyncer/config

vdirsyncer discover google_sync   # opens browser → allow
vdirsyncer sync
khal configure                    # accept defaults, path ~/.calendars/
khal list                         # verify events appear

## 4. Quickshell usage
- Click date in bar (yyyy/MM/dd) → popup calendar. Click again or Esc to close.
- Desktop widget: always-visible PanelWindow layer Background (48px below bar, left 10px). Press Super+C to focus `name:Desktop`.
- CalendarWidget: month grid, Today button, ↻ refresh, day dots for events, agenda for selected day, Add field (`Dinner tomorrow 19:00`), delete via ✕.
- Auto-sync: systemd timer every 5m + refresh on add/delete. Manual: `vdirsyncer sync` or click ↻.

## 5. Secrets
`~/.config/vdirsyncer/config` and `~/.vdirsyncer/google_token` are gitignored, chmod 600. Never commit Client Secret/token. Backup token separately.

## 6. Troubleshooting
- `No khal calendars` → `vdirsyncer sync && khal configure`
- `Token has been expired` → re-run `vdirsyncer discover` (check consent is In production, not Testing)
- `khal new` calendar name → if error, `khal printcalendars` to see actual name, edit `CalendarWidget.qml`/`Time.qml` `khal new --calendar <name>`
- Desktop not visible → `quickshell --no-duplicate` restart, check `hyprctl layers`

## 7. Reauthorization
Since the app is in Testing, repeat this every 7 days:
```
systemctl --user stop vdirsyncer-sinc.timer
mv ~/.vdirsyncer/google_token ~/.vdirsyncer/google_token-$(date +%F-%H%M%S)
vdirsyncer discover google_sync
```
