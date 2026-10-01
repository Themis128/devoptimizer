using System.Collections.ObjectModel;
using System.IO;
using System.Text;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DevOptimizer.App.Models;
using DevOptimizer.App.Services;

namespace DevOptimizer.App.ViewModels;

/// <summary>
/// Sidebar entry: category name plus live command count. "All" is first; the rest are
/// sorted by count descending then name (PS Update-Categories parity).
/// </summary>
public sealed record CategoryItem(string Name, int Count)
{
    public string Display => $"{Name}   ({Count})";
}

/// <summary>One editable parameter row of the selected command's parameter grid.</summary>
public sealed class ParameterInputViewModel : ObservableObject
{
    private string _value = string.Empty;

    public ParameterInputViewModel(string name, string type, bool required, string description)
    {
        Name = name;
        Type = type;
        Required = required;
        Description = description;
    }

    public string Name { get; }

    public string Type { get; }

    public bool Required { get; }

    public string Description { get; }

    public string Value { get => _value; set => SetProperty(ref _value, value); }

    /// <summary>"name * (type)" — the star marks a required parameter (PS Update-Detail parity).</summary>
    public string Signature => Required ? $"{Name} * ({Type})" : $"{Name} ({Type})";
}

/// <summary>
/// Shell ViewModel: category sidebar, live search (Task 2 semantics — category excluded),
/// virtualized command list, detail panel, and the run/elevated/dry-run/output contract
/// of the PowerShell shell.
/// </summary>
public partial class MainViewModel : ObservableObject
{
    internal static int PollIntervalMs { get; set; } = 300;

    private const string AllCategory = "All";

    private readonly string _repoRoot;
    private readonly RegistryService _registryService;
    private readonly SettingsService _settingsService;
    private readonly CommandRunnerService _commandRunnerService;
    private RegistrySnapshot? _snapshot;

    public MainViewModel(string repoRoot, RegistryService registryService, SettingsService settingsService, CommandRunnerService commandRunnerService)
    {
        _repoRoot = repoRoot;
        _registryService = registryService;
        _settingsService = settingsService;
        _commandRunnerService = commandRunnerService;

        Categories = new ObservableCollection<CategoryItem>();
        FilteredCommands = new ObservableCollection<CommandItemViewModel>();
        ParameterInputs = new ObservableCollection<ParameterInputViewModel>();
    }

    /// <summary>
    /// Test seam: when set, replaces CommandRunnerService.Start so unit tests record the
    /// launch call instead of spawning a process. Production wiring leaves it null.
    /// </summary>
    internal Func<CommandDefinition, IReadOnlyDictionary<string, string>, bool, bool, RunArtifacts?>? LaunchOverride { get; set; }

    /// <summary>
    /// Wiring seam: the host sets this to marshal ViewModel updates onto the UI thread
    /// (MainWindow wires Dispatcher.Invoke). Null (tests) runs the action inline.
    /// </summary>
    internal Action<Action>? UiInvoker { get; set; }

    [ObservableProperty]
    private ObservableCollection<CategoryItem> _categories;

    [ObservableProperty]
    private CategoryItem? _selectedCategory;

    [ObservableProperty]
    private string _searchText = string.Empty;

    [ObservableProperty]
    private ObservableCollection<CommandItemViewModel> _filteredCommands;

    [ObservableProperty]
    private CommandItemViewModel? _selectedCommand;

    [ObservableProperty]
    private ObservableCollection<ParameterInputViewModel> _parameterInputs;

    [ObservableProperty]
    private bool _dryRun;

    [ObservableProperty]
    private string _outputText = string.Empty;

    [ObservableProperty]
    private string _statusText = string.Empty;

    [ObservableProperty]
    private int _filteredCount;

    public int TotalCommandCount => _snapshot?.Commands.Count ?? 0;

    /// <summary>The Elevated button is present only for requiresAdmin commands.</summary>
    public bool ShowElevatedButton => SelectedCommand?.RequiresAdmin == true;

    public bool HasParameters => ParameterInputs.Count > 0;

    /// <summary>
    /// Loads the registry snapshot and app settings (DryRun defaults from `defaultDryRun`),
    /// then populates the sidebar and the command list.
    /// </summary>
    public async Task LoadAsync()
    {
        var registryPath = Path.Combine(_repoRoot, "config", "hub-registry.json");
        StatusText = "Loading registry...";

        try
        {
            _snapshot = await Task.Run(() => _registryService.LoadSnapshot(registryPath)).ConfigureAwait(true);
        }
        catch (Exception ex)
        {
            StatusText = $"Failed to load registry: {ex.Message}";
            return;
        }

        var settings = _settingsService.Load(Path.Combine(_repoRoot, "config", "app-settings.json"));
        DryRun = settings.DefaultDryRun;

        RebuildCategories();
        ApplyFilter();
        StatusText = $"Loaded {TotalCommandCount} commands in {Categories.Count - 1} categories.";
    }

    [RelayCommand(CanExecute = nameof(CanRun))]
    private void Run() => RunCore(elevated: false);

    [RelayCommand(CanExecute = nameof(CanRunElevated))]
    private void RunElevated() => RunCore(elevated: true);

    private bool CanRun() => SelectedCommand is not null && RequiredParametersSatisfied();

    private bool CanRunElevated() => CanRun() && (SelectedCommand?.RequiresAdmin ?? false);

    private void NotifyRunCommandsChanged()
    {
        RunCommand.NotifyCanExecuteChanged();
        RunElevatedCommand.NotifyCanExecuteChanged();
    }

    private void RunCore(bool elevated)
    {
        var selection = SelectedCommand;
        if (selection is null)
        {
            return;
        }

        // Security gate: only definitions sourced from the loaded registry snapshot may be
        // launched — never free-text command names accepted from UI input.
        if (!IsRegistrySourced(selection.Definition))
        {
            StatusText = $"Refusing to run '{selection.Name}': not in the loaded registry snapshot.";
            return;
        }

        if (!RequiredParametersSatisfied())
        {
            StatusText = $"Fill in the required parameters for '{selection.Name}' first.";
            return;
        }

        var parameters = CollectParameterValues();
        var stamp = DateTime.Now.ToString("HH:mm:ss");
        StatusText = $"Running '{selection.Name}'...";

        var artifacts = Launch(selection.Definition, parameters, elevated, DryRun);
        if (artifacts is null)
        {
            // Interactive console path: no per-run artifacts exist (Start-HubRun parity).
            AppendOutput($"[{stamp}] '{selection.Name}' is an interactive tool - opened it in a separate console window. Use that window; its output cannot be captured here.");
            StatusText = $"Opened '{selection.Name}' in a console window.";
            return;
        }

        AppendOutput($"[{stamp}] Launched '{selection.Name}'{(elevated ? " (elevated)" : string.Empty)}{(DryRun ? " (dry run)" : string.Empty)}.");
        _ = PollRunOutputAsync(artifacts);
    }

    private RunArtifacts? Launch(CommandDefinition command, IReadOnlyDictionary<string, string> values, bool elevated, bool dryRun)
    {
        if (LaunchOverride is { } launchOverride)
        {
            return launchOverride(command, values, elevated, dryRun);
        }

        var payload = values.ToDictionary(kv => kv.Key, kv => (object?)kv.Value);
        return _commandRunnerService.Start(command, payload, elevated, dryRun);
    }

    /// <summary>Polls the run log until the done-file appears, printing the exit line.</summary>
    private async Task PollRunOutputAsync(RunArtifacts artifacts)
    {
        var offset = 0L;
        while (true)
        {
            if (File.Exists(artifacts.LogFile))
            {
                offset = AppendNewLogLines(artifacts.LogFile, offset);
            }

            if (File.Exists(artifacts.DoneFile))
            {
                if (File.Exists(artifacts.LogFile))
                {
                    AppendNewLogLines(artifacts.LogFile, offset);
                }

                var exitLine = ReadDoneLine(artifacts.DoneFile);
                AppendOutput($"[{DateTime.Now:HH:mm:ss}] run finished: {exitLine}");
                StatusText = $"Finished '{artifacts.RunId}': {exitLine}";
                break;
            }

            await Task.Delay(PollIntervalMs).ConfigureAwait(true);
        }
    }

    /// <summary>Appends complete new lines of the run log past the byte offset; tolerant of concurrent writes.</summary>
    private long AppendNewLogLines(string logFile, long offset)
    {
        try
        {
            using var stream = new FileStream(logFile, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
            if (stream.Length <= offset)
            {
                return offset;
            }

            stream.Seek(offset, SeekOrigin.Begin);
            var buffer = new byte[stream.Length - offset];
            var read = stream.Read(buffer, 0, buffer.Length);
            var text = Encoding.UTF8.GetString(buffer, 0, read);

            var lastNewline = text.LastIndexOf('\n');
            if (lastNewline < 0)
            {
                return offset;
            }

            var complete = text[..(lastNewline + 1)];
            foreach (var line in complete.Split('\n'))
            {
                var trimmed = line.TrimEnd('\r');
                if (trimmed.Length > 0)
                {
                    AppendOutput(trimmed);
                }
            }

            return offset + Encoding.UTF8.GetByteCount(complete);
        }
        catch (IOException)
        {
            return offset; // log momentarily locked by the runner; retry next tick
        }
    }

    private static string ReadDoneLine(string doneFile)
    {
        try
        {
            return File.ReadAllText(doneFile).Trim();
        }
        catch (IOException)
        {
            return string.Empty;
        }
    }

    private void AppendOutput(string line)
    {
        Action append = () => OutputText += line + Environment.NewLine;
        if (UiInvoker is { } invoker)
        {
            invoker(append);
        }
        else
        {
            append();
        }
    }

    private void RebuildCategories()
    {
        var byCategory = _snapshot!.Commands
            .GroupBy(c => c.Category, StringComparer.OrdinalIgnoreCase)
            .OrderByDescending(g => g.Count())
            .ThenBy(g => g.Key, StringComparer.OrdinalIgnoreCase)
            .Select(g => new CategoryItem(g.Key, g.Count()));

        var categories = new ObservableCollection<CategoryItem> { new(AllCategory, _snapshot.Commands.Count) };
        foreach (var item in byCategory)
        {
            categories.Add(item);
        }

        Categories = categories;
        SelectedCategory = categories[0];
    }

    private void ApplyFilter()
    {
        if (_snapshot is null)
        {
            FilteredCommands = new ObservableCollection<CommandItemViewModel>();
            FilteredCount = 0;
            return;
        }

        IEnumerable<CommandDefinition> source = _snapshot.Commands;
        var category = SelectedCategory;
        if (category is not null && category.Name != AllCategory)
        {
            source = RegistryService.ByCategory(_snapshot, category.Name);
        }

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            var scoped = new RegistrySnapshot { Commands = source.ToList() };
            source = RegistryService.Search(scoped, SearchText);
        }

        var matches = source.OrderBy(c => c.Name, StringComparer.OrdinalIgnoreCase).ToList();
        FilteredCommands = new ObservableCollection<CommandItemViewModel>(matches.Select(d => new CommandItemViewModel(d)));
        FilteredCount = FilteredCommands.Count;

        // Preserve the selection only if it survives the new filter (PS Update-CommandView parity).
        var previous = SelectedCommand;
        if (previous is not null && matches.All(m => m.Name != previous.Name))
        {
            SelectedCommand = null;
        }
    }

    private void RebuildParameterInputs()
    {
        var inputs = new ObservableCollection<ParameterInputViewModel>();
        var definitions = SelectedCommand?.Definition.Parameters;
        if (definitions is not null)
        {
            foreach (var parameter in definitions)
            {
                var input = new ParameterInputViewModel(parameter.Name, parameter.Type, parameter.Required, parameter.Description);
                input.PropertyChanged += (_, args) =>
                {
                    if (args.PropertyName == nameof(ParameterInputViewModel.Value))
                    {
                        NotifyRunCommandsChanged();
                    }
                };
                inputs.Add(input);
            }
        }

        ParameterInputs = inputs;
        OnPropertyChanged(nameof(HasParameters));
    }

    private bool IsRegistrySourced(CommandDefinition definition)
        => _snapshot?.Commands.Any(c => c.Name == definition.Name && c.Path == definition.Path) == true;

    private bool RequiredParametersSatisfied()
        => ParameterInputs.Where(p => p.Required).All(p => !string.IsNullOrWhiteSpace(p.Value));

    private IReadOnlyDictionary<string, string> CollectParameterValues()
        => ParameterInputs
            .Where(p => !string.IsNullOrWhiteSpace(p.Value))
            .ToDictionary(p => p.Name, p => p.Value.Trim());

    partial void OnSelectedCategoryChanged(CategoryItem? value) => ApplyFilter();

    partial void OnSearchTextChanged(string value) => ApplyFilter();

    partial void OnSelectedCommandChanged(CommandItemViewModel? value)
    {
        RebuildParameterInputs();
        OnPropertyChanged(nameof(ShowElevatedButton));
        NotifyRunCommandsChanged();
    }
}
