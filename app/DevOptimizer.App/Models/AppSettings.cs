using System.Text.Json.Serialization;

namespace DevOptimizer.App.Models;

/// <summary>
/// Typed app settings. Keys, defaults, and valid-value sets mirror
/// $script:SettingsSchema in app/DevOptimizer-AppCore.psm1 EXACTLY (lines 28-34):
///   theme           (string) default "dark"  valid: dark, light            (line 29)
///   toasts          (bool)   default true                                  (line 30)
///   autostart       (bool)   default false                                 (line 31)
///   defaultDryRun   (bool)   default false                                 (line 32)
///   logLevel        (string) default "info" valid: debug, info, warn, error (line 33)
///   toastMinSeconds (int)    default 10                                    (line 34)
/// JSON key names are the exact camelCase names Save-AppSettings writes (line 78).
/// </summary>
public sealed class AppSettings
{
    [JsonPropertyName("theme")]
    public string Theme { get; set; } = "dark"; // AppCore.psm1:29

    [JsonPropertyName("toasts")]
    public bool Toasts { get; set; } = true; // AppCore.psm1:30

    [JsonPropertyName("autostart")]
    public bool Autostart { get; set; } = false; // AppCore.psm1:31

    [JsonPropertyName("defaultDryRun")]
    public bool DefaultDryRun { get; set; } = false; // AppCore.psm1:32 — regression-locked key name (NOT "dryRunDefault")

    [JsonPropertyName("logLevel")]
    public string LogLevel { get; set; } = "info"; // AppCore.psm1:33

    [JsonPropertyName("toastMinSeconds")]
    public int ToastMinSeconds { get; set; } = 10; // AppCore.psm1:34
}
