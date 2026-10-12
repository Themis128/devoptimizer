$apps = @(
    'Discord', 'Slack', 'Zoom', 'Teams', 'Skype', 'Telegram', 'WhatsApp', 
    'Signal', 'Messenger', 'Facebook', 'Instagram', 'Twitter', 'X', 
    'LinkedIn', 'Reddit', 'TikTok', 'Spotify', 'YouTube', 'Twitch',
    'Bluesky', 'Mastodon', 'Threads'
)

"=== AppData\Local ==="
ls $env:LOCALAPPDATA | Where-Object { $_.Name -match '(?i)discord|slack|zoom|teams|skype|telegram|whatsapp|signal|messenger|facebook|instagram|twitter|linkedin|reddit|tiktok|spotify|youtube|twitch|bluesky|mastodon|threads' } | Select-Object Name, FullName

"=== AppData\Roaming ==="
ls $env:APPDATA | Where-Object { $_.Name -match '(?i)discord|slack|zoom|teams|skype|telegram|whatsapp|signal|messenger|facebook|instagram|twitter|linkedin|reddit|tiktok|spotify|youtube|twitch|bluesky|mastodon|threads' } | Select-Object Name, FullName

"=== Program Files ==="
ls $env:PROGRAMFILES | Where-Object { $_.Name -match '(?i)discord|slack|zoom|teams|skype|telegram|whatsapp|signal|messenger|facebook|instagram|twitter|linkedin|reddit|tiktok|spotify|youtube|twitch|bluesky|mastodon|threads' } | Select-Object Name, FullName

"=== Program Files (x86) ==="
ls ${env:PROGRAMFILES(X86)} | Where-Object { $_.Name -match '(?i)discord|slack|zoom|teams|skype|telegram|whatsapp|signal|messenger|facebook|instagram|twitter|linkedin|reddit|tiktok|spotify|youtube|twitch|bluesky|mastodon|threads' } | Select-Object Name, FullName