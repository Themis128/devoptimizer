namespace DevOptimizer.App.Models;

/// <summary>
/// Typed view of the whole config/hub-registry.json document
/// (top-level object: version, generated, categories, commands).
/// </summary>
public sealed class RegistrySnapshot
{
    public string Version { get; set; } = string.Empty;

    public string Generated { get; set; } = string.Empty;

    public List<RegistryCategory> Categories { get; set; } = [];

    public List<CommandDefinition> Commands { get; set; } = [];
}

/// <summary>Entry of the top-level "categories" array of the registry.</summary>
public sealed class RegistryCategory
{
    public string Name { get; set; } = string.Empty;

    public int CommandCount { get; set; }

    public string LastUpdated { get; set; } = string.Empty;
}
