namespace DevOptimizer.App.Models;

/// <summary>
/// One command entry from the "commands" array of config/hub-registry.json.
/// Registry JSON uses camelCase field names; deserialization is case-insensitive
/// (see RegistryService.JsonOptions), so no per-property attributes are needed.
/// </summary>
public sealed class CommandDefinition
{
    public string Name { get; set; } = string.Empty;

    public string Path { get; set; } = string.Empty;

    public string Category { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    public bool RequiresAdmin { get; set; }

    /// <summary>"powershell" or "cmd" — the engine that owns the entry point.</summary>
    public string EntryPoint { get; set; } = string.Empty;

    public List<CommandParameter> Parameters { get; set; } = [];

    public List<string> Tags { get; set; } = [];

    /// <summary>Free-form producer metadata (author, created, modified, sourceUrl, version).</summary>
    public Dictionary<string, string?> Metadata { get; set; } = new();
}

/// <summary>Typed parameter entry of a command ("parameters" array element).</summary>
public sealed class CommandParameter
{
    public string Name { get; set; } = string.Empty;

    public string Type { get; set; } = string.Empty;

    public string Description { get; set; } = string.Empty;

    public bool Required { get; set; }
}
