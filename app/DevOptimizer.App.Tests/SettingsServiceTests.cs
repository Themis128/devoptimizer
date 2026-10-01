using System.IO;
using System.Text;
using DevOptimizer.App.Models;
using DevOptimizer.App.Services;
using Xunit;

namespace DevOptimizer.App.Tests;

public class SettingsServiceTests
{
    // All tests are temp-scoped: the live config/app-settings.json is NEVER touched.

    private readonly SettingsService _service = new();

    private string TempSettingsPath()
    {
        var dir = Path.Combine(Path.GetTempPath(), "doapp-settingstests-" + Guid.NewGuid().ToString("N"));
        return Path.Combine(dir, "config", "app-settings.json"); // dir intentionally not created yet
    }

    private static void WriteFile(string path, string content, bool withBom = false)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var encoding = withBom ? new UTF8Encoding(encoderShouldEmitUTF8Identifier: true) : new UTF8Encoding(false);
        File.WriteAllText(path, content, encoding);
    }

    private static void Cleanup(string path)
    {
        var root = Path.GetDirectoryName(Path.GetDirectoryName(path))!;
        try { Directory.Delete(root, recursive: true); } catch (IOException) { }
    }

    // ------------------------------------------------------------------
    // Schema regression locks — $script:SettingsSchema, AppCore.psm1:28-34
    // (defaults also flow from Get-DefaultAppSettings, lines 37-42).
    // ------------------------------------------------------------------

    [Fact]
    public void Defaults_LockSchema()
    {
        // AppCore.psm1:29 — theme (string), Default 'dark', Valid dark/light
        Assert.Equal("dark", SettingsService.Defaults().Theme);
        // AppCore.psm1:30 — toasts (bool), Default $true
        Assert.True(SettingsService.Defaults().Toasts);
        // AppCore.psm1:31 — autostart (bool), Default $false
        Assert.False(SettingsService.Defaults().Autostart);
        // AppCore.psm1:32 — defaultDryRun (bool), Default $false (key is `defaultDryRun`, NOT `dryRunDefault`)
        Assert.False(SettingsService.Defaults().DefaultDryRun);
        // AppCore.psm1:33 — logLevel (string), Default 'info', Valid debug/info/warn/error
        Assert.Equal("info", SettingsService.Defaults().LogLevel);
        // AppCore.psm1:34 — toastMinSeconds (int), Default 10
        Assert.Equal(10, SettingsService.Defaults().ToastMinSeconds);
    }

    [Fact]
    public void ValidValueSets_LockSchema()
    {
        // AppCore.psm1:29 — Valid @('dark', 'light')
        Assert.Equal(new[] { "dark", "light" }, SettingsService.ValidThemes);
        // AppCore.psm1:33 — Valid @('debug', 'info', 'warn', 'error')
        Assert.Equal(new[] { "debug", "info", "warn", "error" }, SettingsService.ValidLogLevels);
    }

    // ------------------------------------------------------------------
    // Load semantics — Get-AppSettings, AppCore.psm1:45-64
    // ------------------------------------------------------------------

    [Fact]
    public void Load_MissingFile_YieldsDefaults()
    {
        var path = TempSettingsPath();
        try
        {
            Assert.False(File.Exists(path));
            Assert.Equal("dark", _service.Load(path).Theme);
            Assert.True(_service.Load(path).Toasts);
            Assert.False(_service.Load(path).Autostart);
            Assert.False(_service.Load(path).DefaultDryRun);
            Assert.Equal("info", _service.Load(path).LogLevel);
            Assert.Equal(10, _service.Load(path).ToastMinSeconds);
        }
        finally { Cleanup(path); }
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    public void Load_EmptyPath_YieldsDefaults(string? path)
    {
        var settings = _service.Load(path);
        Assert.Equal("dark", settings.Theme);
        Assert.Equal(10, settings.ToastMinSeconds);
    }

    [Fact]
    public void Load_CorruptedFile_YieldsDefaults()
    {
        // AppCore.psm1:59-61 — corrupted settings file falls back to defaults
        var path = TempSettingsPath();
        try
        {
            WriteFile(path, "{ this is not json ]");
            var settings = _service.Load(path);
            Assert.Equal("dark", settings.Theme);
            Assert.True(settings.Toasts);
            Assert.Equal("info", settings.LogLevel);
            Assert.Equal(10, settings.ToastMinSeconds);
        }
        finally { Cleanup(path); }
    }

    [Fact]
    public void Load_EmptyFile_YieldsDefaults()
    {
        var path = TempSettingsPath();
        try
        {
            WriteFile(path, string.Empty);
            var settings = _service.Load(path);
            Assert.Equal("dark", settings.Theme);
            Assert.Equal("info", settings.LogLevel);
        }
        finally { Cleanup(path); }
    }

    [Fact]
    public void Load_PerKeyFallback_OneInvalidKeyDoesNotDiscardValidOthers()
    {
        // AppCore.psm1:52-58 — each schema key is validated independently: "neon" is not
        // in the theme valid set (line 29) so theme keeps its default, "WARN" IS in the
        // logLevel valid set (line 33, case-insensitive membership with original casing
        // preserved), and the invalid toastMinSeconds string does not touch the valid
        // toasts value.
        var path = TempSettingsPath();
        try
        {
            WriteFile(path, """
                {
                  "theme": "neon",
                  "logLevel": "WARN",
                  "toasts": false,
                  "defaultDryRun": true,
                  "toastMinSeconds": "not-a-number"
                }
                """);

            var settings = _service.Load(path);
            Assert.Equal("dark", settings.Theme);          // invalid -> default (per-key fallback)
            Assert.Equal("WARN", settings.LogLevel);       // valid, original casing preserved
            Assert.False(settings.Toasts);                 // valid bool kept
            Assert.True(settings.DefaultDryRun);           // valid bool kept
            Assert.Equal(10, settings.ToastMinSeconds);    // invalid -> default
        }
        finally { Cleanup(path); }
    }

    [Fact]
    public void Load_CaseInsensitiveKeys_Applied()
    {
        // AppCore.psm1:52-53 — property-name matching is case-insensitive
        var path = TempSettingsPath();
        try
        {
            WriteFile(path, """{ "Theme": "light", "LOGLEVEL": "error", "DEFAULTDRYRUN": true }""");
            var settings = _service.Load(path);
            Assert.Equal("light", settings.Theme);
            Assert.Equal("error", settings.LogLevel);
            Assert.True(settings.DefaultDryRun);
        }
        finally { Cleanup(path); }
    }

    [Fact]
    public void Load_UnknownKeys_Ignored()
    {
        // AppCore.psm1:52 — the loop iterates schema keys only; unknown JSON keys are ignored
        var path = TempSettingsPath();
        try
        {
            WriteFile(path, """{ "theme": "light", "bogusKey": 123, "dryRunDefault": true }""");
            var settings = _service.Load(path);
            Assert.Equal("light", settings.Theme);
            Assert.False(settings.DefaultDryRun); // `dryRunDefault` is NOT a schema key (regression: 32 is `defaultDryRun`)
        }
        finally { Cleanup(path); }
    }

    [Fact]
    public void Load_Utf8Bom_Tolerated()
    {
        // Files written by the legacy PS 5.1 app carry a UTF-8 BOM (AppCore.psm1:78)
        var path = TempSettingsPath();
        try
        {
            WriteFile(path, """{ "theme": "light" }""", withBom: true);
            Assert.Equal("light", _service.Load(path).Theme);
        }
        finally { Cleanup(path); }
    }

    [Fact]
    public void Load_Coercions_MirrorAsOperator()
    {
        // AppCore.psm1:58 — `$v -as $schema['Type']` accepts "true"/"false" strings for
        // bool keys and numeric strings for int keys.
        var path = TempSettingsPath();
        try
        {
            WriteFile(path, """{ "toasts": "false", "autostart": "true", "toastMinSeconds": "25" }""");
            var settings = _service.Load(path);
            Assert.False(settings.Toasts);
            Assert.True(settings.Autostart);
            Assert.Equal(25, settings.ToastMinSeconds);
        }
        finally { Cleanup(path); }
    }

    // ------------------------------------------------------------------
    // Save/round-trip — Save-AppSettings, AppCore.psm1:66-80 (temp dir only)
    // ------------------------------------------------------------------

    [Fact]
    public void RoundTrip_SaveThenLoad_PreservesAllKeys_AndCreatesDirectory()
    {
        var path = TempSettingsPath(); // parent "config" dir does not exist yet
        try
        {
            var toSave = new AppSettings
            {
                Theme = "light",
                Toasts = false,
                Autostart = true,
                DefaultDryRun = true,
                LogLevel = "debug",
                ToastMinSeconds = 42,
            };

            _service.Save(path, toSave);

            Assert.True(File.Exists(path), "Save must create the destination directory (AppCore.psm1:75-76)");

            // Writer parity: PS 5.1 Set-Content -Encoding UTF8 emits a UTF-8 BOM (AppCore.psm1:78)
            var firstBytes = File.ReadAllBytes(path)[..3];
            Assert.Equal(new byte[] { 0xEF, 0xBB, 0xBF }, firstBytes);

            var loaded = _service.Load(path);
            Assert.Equal("light", loaded.Theme);
            Assert.False(loaded.Toasts);
            Assert.True(loaded.Autostart);
            Assert.True(loaded.DefaultDryRun);
            Assert.Equal("debug", loaded.LogLevel);
            Assert.Equal(42, loaded.ToastMinSeconds);
        }
        finally { Cleanup(path); }
    }

    [Fact]
    public void RoundTrip_InvalidValueInFile_FallsBackToDefaultOnLoad()
    {
        var path = TempSettingsPath();
        try
        {
            _service.Save(path, SettingsService.Defaults());

            // Simulate a hand-edited file with an out-of-schema value
            var text = File.ReadAllText(path);
            File.WriteAllText(path, text.Replace("\"dark\"", "\"neon\""));

            Assert.Equal("dark", _service.Load(path).Theme);
        }
        finally { Cleanup(path); }
    }

    [Fact]
    public void Save_WritesExactSchemaKeyNames()
    {
        // Save-AppSettings writes the exact schema keys (AppCore.psm1:71-78)
        var path = TempSettingsPath();
        try
        {
            _service.Save(path, SettingsService.Defaults());
            var text = File.ReadAllText(path);

            Assert.Contains("\"theme\"", text);
            Assert.Contains("\"toasts\"", text);
            Assert.Contains("\"autostart\"", text);
            Assert.Contains("\"defaultDryRun\"", text);
            Assert.Contains("\"logLevel\"", text);
            Assert.Contains("\"toastMinSeconds\"", text);
            Assert.DoesNotContain("\"dryRunDefault\"", text);
        }
        finally { Cleanup(path); }
    }
}
