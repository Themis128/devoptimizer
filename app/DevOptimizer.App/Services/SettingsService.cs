using System.Globalization;
using System.IO;
using System.Text;
using System.Text.Json;
using DevOptimizer.App.Models;

namespace DevOptimizer.App.Services;

/// <summary>
/// Loads and saves config/app-settings.json with the same schema, defaults, and
/// per-key fallback semantics as Get-AppSettings / Save-AppSettings in
/// app/DevOptimizer-AppCore.psm1 (lines 45-80).
/// </summary>
public sealed class SettingsService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true, // ConvertTo-Json writes indented output (AppCore.psm1:78)
    };

    // Valid-value sets — $script:SettingsSchema lines 29 and 33 (regression-locked).
    public static IReadOnlyList<string> ValidThemes { get; } = new[] { "dark", "light" };
    public static IReadOnlyList<string> ValidLogLevels { get; } = new[] { "debug", "info", "warn", "error" };

    private static readonly UTF8Encoding Utf8WithBom = new(encoderShouldEmitUTF8Identifier: true);

    /// <summary>Fresh defaults — Get-DefaultAppSettings (AppCore.psm1:37-42).</summary>
    public static AppSettings Defaults() => new();

    /// <summary>
    /// Loads settings with Get-AppSettings semantics (AppCore.psm1:45-64):
    /// missing/null path or unreadable/corrupted file yields defaults; valid keys are
    /// applied per key (one invalid key keeps its default and never discards valid
    /// others); key matching and valid-set membership are case-insensitive.
    /// </summary>
    public AppSettings Load(string? settingsPath)
    {
        var settings = Defaults();

        if (string.IsNullOrEmpty(settingsPath) || !File.Exists(settingsPath))
        {
            return settings;
        }

        Dictionary<string, JsonElement>? raw;
        try
        {
            var bytes = File.ReadAllBytes(settingsPath);
            var payload = bytes.AsSpan();
            // Legacy PS 5.1 writers emit a UTF-8 BOM (Set-Content -Encoding UTF8); strip
            // it before System.Text.Json parsing, mirroring RegistryService.
            if (payload.Length >= 3 && payload[0] == 0xEF && payload[1] == 0xBB && payload[2] == 0xBF)
            {
                payload = payload[3..];
            }

            raw = JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(payload);
        }
        catch (Exception ex) when (ex is JsonException or FormatException or InvalidOperationException)
        {
            // corrupted settings file falls back to defaults (AppCore.psm1:59-61)
            return settings;
        }

        if (raw is null)
        {
            return settings;
        }

        foreach (var entry in raw)
        {
            switch (entry.Key.ToLowerInvariant())
            {
                case "theme":
                    if (CoerceValidatedString(entry.Value, ValidThemes) is { } theme)
                    {
                        settings.Theme = theme;
                    }

                    break;

                case "toasts":
                    if (TryCoerceBool(entry.Value, out var toasts))
                    {
                        settings.Toasts = toasts;
                    }

                    break;

                case "autostart":
                    if (TryCoerceBool(entry.Value, out var autostart))
                    {
                        settings.Autostart = autostart;
                    }

                    break;

                case "defaultdryrun":
                    if (TryCoerceBool(entry.Value, out var defaultDryRun))
                    {
                        settings.DefaultDryRun = defaultDryRun;
                    }

                    break;

                case "loglevel":
                    if (CoerceValidatedString(entry.Value, ValidLogLevels) is { } logLevel)
                    {
                        settings.LogLevel = logLevel;
                    }

                    break;

                case "toastminseconds":
                    if (TryCoerceInt(entry.Value, out var toastMinSeconds))
                    {
                        settings.ToastMinSeconds = toastMinSeconds;
                    }

                    break;
            }
        }

        return settings;
    }

    /// <summary>
    /// Persists settings with Save-AppSettings semantics (AppCore.psm1:66-80): the caller
    /// passes a fully populated AppSettings (Defaults() merged with overrides — the typed
    /// equivalent of Save-AppSettings's clean-slate defaults-first merge), the destination
    /// directory is created if missing, and the file is written as indented JSON in UTF-8
    /// with BOM (PS 5.1 Set-Content -Encoding UTF8 parity, AppCore.psm1:78).
    /// </summary>
    public void Save(string settingsPath, AppSettings settings)
    {
        var dir = Path.GetDirectoryName(settingsPath);
        if (!string.IsNullOrEmpty(dir))
        {
            Directory.CreateDirectory(dir);
        }

        var payload = JsonSerializer.SerializeToUtf8Bytes(settings, JsonOptions);
        var preamble = Utf8WithBom.GetPreamble();
        var bytes = new byte[preamble.Length + payload.Length];
        preamble.CopyTo(bytes, 0);
        payload.CopyTo(bytes, preamble.Length);
        File.WriteAllBytes(settingsPath, bytes);
    }

    // Mirrors the Valid gate (AppCore.psm1:54): membership is case-insensitive
    // (-notcontains), the ORIGINAL casing is preserved, and non-string values fail
    // the gate so the default is kept. Returns null to signal "keep default".
    private static string? CoerceValidatedString(JsonElement value, IReadOnlyList<string> valid)
    {
        if (value.ValueKind != JsonValueKind.String)
        {
            return null;
        }

        var s = value.GetString();
        if (s is null)
        {
            return null;
        }

        return valid.Contains(s, StringComparer.OrdinalIgnoreCase) ? s : null;
    }

    // Mirrors "-as [bool]" (AppCore.psm1:58): JSON booleans, "true"/"false" strings
    // (case-insensitive), and numbers (nonzero -> true). Anything else keeps the default.
    private static bool TryCoerceBool(JsonElement value, out bool result)
    {
        switch (value.ValueKind)
        {
            case JsonValueKind.True or JsonValueKind.False:
                result = value.GetBoolean();
                return true;

            case JsonValueKind.String:
                return bool.TryParse(value.GetString(), out result);

            case JsonValueKind.Number:
                try
                {
                    result = value.GetDouble() != 0;
                    return true;
                }
                catch (FormatException)
                {
                    result = default;
                    return false;
                }

            default:
                result = default;
                return false;
        }
    }

    // Mirrors "-as [int]" (AppCore.psm1:58): JSON numbers (banker's rounding like the PS
    // [int] cast), numeric strings (invariant), and booleans (true -> 1, false -> 0).
    // Anything else keeps the default.
    private static bool TryCoerceInt(JsonElement value, out int result)
    {
        switch (value.ValueKind)
        {
            case JsonValueKind.Number:
                try
                {
                    result = Convert.ToInt32(value.GetDouble());
                    return true;
                }
                catch (Exception ex) when (ex is FormatException or OverflowException)
                {
                    result = default;
                    return false;
                }

            case JsonValueKind.String:
                return int.TryParse(value.GetString(), NumberStyles.Integer, CultureInfo.InvariantCulture, out result);

            case JsonValueKind.True:
                result = 1;
                return true;

            case JsonValueKind.False:
                result = 0;
                return true;

            default:
                result = default;
                return false;
        }
    }
}
