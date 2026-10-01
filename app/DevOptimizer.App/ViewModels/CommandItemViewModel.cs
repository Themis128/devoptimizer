using DevOptimizer.App.Models;

namespace DevOptimizer.App.ViewModels;

/// <summary>
/// Display wrapper for one CommandDefinition row of the command list. Immutable over the
/// registry-sourced definition — only registry-sourced definitions are ever wrapped and run.
/// </summary>
public sealed class CommandItemViewModel
{
    public CommandItemViewModel(CommandDefinition definition) => Definition = definition;

    public CommandDefinition Definition { get; }

    public string Name => Definition.Name;

    public string Category => Definition.Category;

    public string Description => Definition.Description;

    public string Path => Definition.Path;

    public string EntryPoint => Definition.EntryPoint;

    public bool RequiresAdmin => Definition.RequiresAdmin;

    public string TagsDisplay => Definition.Tags.Count == 0 ? "-" : string.Join(", ", Definition.Tags);

    /// <summary>"category: X    entry: Y" line of the detail panel (PS Update-Detail parity).</summary>
    public string CategoryAndEntry => $"category: {Category}    entry: {EntryPoint}";
}
