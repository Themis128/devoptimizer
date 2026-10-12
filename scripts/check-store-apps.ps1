$apps = @(
    '5319275A.WhatsAppDesktop',
    '7EE7776C.LinkedInforWindows',
    'BytedancePte.Ltd.TikTok',
    'com.tinyspeck.slackdesktop',
    'FACEBOOK.FACEBOOK',
    'Facebook.InstagramBeta',
    'Instagram.ThreadsanInstagramapp',
    'MSTeams',
    'SpotifyAB.SpotifyMusic',
    'TelegramMessengerLLP.TelegramDesktop',
    'www.messenger.com-43D6998D'
)

foreach ($app in $apps) {
    $pkg = Get-AppxPackage -Name $app -ErrorAction SilentlyContinue
    if ($pkg) {
        Write-Host "=== $($pkg.Name) ==="
        Write-Host "  Version: $($pkg.Version)"
        Write-Host "  Publisher: $($pkg.PublisherDisplayName)"
        Write-Host "  InstallLocation: $($pkg.InstallLocation)"
        Write-Host "  IsFramework: $($pkg.IsFramework)"
        Write-Host "  IsResourcePackage: $($pkg.IsResourcePackage)"
        Write-Host "  Status: $($pkg.Status)"
        Write-Host ""
    }
}