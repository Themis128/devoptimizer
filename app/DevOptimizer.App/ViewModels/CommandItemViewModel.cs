using DevOptimizer.App.Models;
using System.Text.RegularExpressions;

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

    // Search highlighting properties
    private string? _highlightedName;
    private string? _highlightedDescription;

    /// <summary>
    /// Gets the name with search terms highlighted (returns HTML-like markup for UI binding).
    /// Returns plain name if no search term or no match.
    /// </summary>
    public string HighlightedName => _highlightedName ?? Name;

    /// <summary>
    /// Gets the description with search terms highlighted (returns HTML-like markup for UI binding).
    /// Returns plain description if no search term or no match.
    /// </summary>
    public string HighlightedDescription => _highlightedDescription ?? Description;

    /// <summary>
    /// Updates highlighted text based on search term.
    /// </summary>
    /// <param name="searchTerm">The search term to highlight</param>
    public void UpdateHighlightedText(string? searchTerm)
    {
        if (string.IsNullOrWhiteSpace(searchTerm))
        {
            _highlightedName = null;
            _highlightedDescription = null;
            return;
        }

        // Escape special regex characters in search term
        string escapedTerm = Regex.Escape(searchTerm.Trim());

        // Highlight matches in name (case-insensitive)
        _highlightedName = Regex.IsMatch(Name, escapedTerm, RegexOptions.IgnoreCase)
            ? Regex.Replace(Name, escapedTerm, 
                  match => $"<Highlight>{match.Value}</Highlight>", 
                  RegexOptions.IgnoreCase)
            : Name;

        // Highlight matches in description (case-insensitive)
        _highlightedDescription = Regex.IsMatch(Description, escapedTerm, RegexOptions.IgnoreCase)
            ? Regex.Replace(Description, escapedTerm, 
                  match => $"<Highlight>{match.Value}</Highlight>", 
                  RegexOptions.IgnoreCase)
            : Description;
    }
}
