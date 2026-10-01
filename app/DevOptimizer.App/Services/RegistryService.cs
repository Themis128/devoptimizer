using System.IO;
using System.Text.Json;
using DevOptimizer.App.Models;

namespace DevOptimizer.App.Services;

/// <summary>
/// Typed loader and pure filter/search over the hub registry JSON.
/// </summary>
public sealed class RegistryService
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    /// <summary>
    /// Loads and deserializes the registry file. UTF-8 BOM is tolerated — it is
    /// stripped before System.Text.Json parsing (the producer emits EF BB BF).
    /// </summary>
    public RegistrySnapshot LoadSnapshot(string registryPath)
    {
        var bytes = File.ReadAllBytes(registryPath);

        var payload = bytes.AsSpan();
        if (payload.Length >= 3 && payload[0] == 0xEF && payload[1] == 0xBB && payload[2] == 0xBF)
        {
            payload = payload[3..];
        }

        RegistrySnapshot snapshot = JsonSerializer.Deserialize<RegistrySnapshot>(payload, JsonOptions) ?? new RegistrySnapshot();
        snapshot.Commands ??= new List<CommandDefinition>();
        return snapshot;
    }

    /// <summary>
    /// Case-insensitive substring search across name/description/path/tags with the
    /// category EXCLUDED, mirroring Test-CommandFilter (app/DevOptimizer-AppCore.psm1:86-97).
    /// Including the category made a search for a category name match every command in
    /// that category (2026-09-26 regression). An empty/whitespace query matches everything.
    /// </summary>
    public static IReadOnlyList<CommandDefinition> Search(RegistrySnapshot snapshot, string? query)
    {
        if (string.IsNullOrWhiteSpace(query))
        {
            return snapshot.Commands;
        }

        var needle = query.Trim();
        return snapshot.Commands
            .Where(c => Haystack(c).Contains(needle, StringComparison.OrdinalIgnoreCase))
            .ToList();
    }

    /// <summary>Returns commands whose category equals <paramref name="category"/> (case-insensitive).</summary>
    public static IReadOnlyList<CommandDefinition> ByCategory(RegistrySnapshot snapshot, string category)
    {
        return snapshot.Commands
            .Where(c => string.Equals(c.Category, category, StringComparison.OrdinalIgnoreCase))
            .ToList();
    }

    // "{0} {1} {2} {3}" -f name, description, path, (tags -join ' ') — the category is
    // deliberately absent from the haystack (see Search).
    private static string Haystack(CommandDefinition command) =>
        string.Join(' ', command.Name, command.Description, command.Path, string.Join(' ', command.Tags));
}
