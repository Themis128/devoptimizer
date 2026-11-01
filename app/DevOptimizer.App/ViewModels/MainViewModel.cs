using System.Collections.ObjectModel;
using System.IO;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Windows.Input;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using DevOptimizer.App.Models;
using DevOptimizer.App.Services;
using DevOptimizer.App.UserControls;

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
    internal static int SearchDebounceMs { get; set; } = 300;

    private const string AllCategory = "All";

    private readonly string _repoRoot;
    private readonly RegistryService _registryService;
    private readonly SettingsService _settingsService;
    private readonly CommandRunnerService _commandRunnerService;
    private RegistrySnapshot? _snapshot;
    
    // Search debouncing
    private CancellationTokenSource? _searchDebounceCts;
    
    // Search scope: true = search within selected category, false = search all categories
    private bool _searchWithinCategory = true;

    public MainViewModel(string repoRoot, RegistryService registryService, SettingsService settingsService, CommandRunnerService commandRunnerService)
    {
        _repoRoot = repoRoot;
        _registryService = registryService;
        _settingsService = settingsService;
        _commandRunnerService = commandRunnerService;

        Categories = new ObservableCollection<CategoryItem>();
        FilteredCommands = new ObservableCollection<CommandItemViewModel>();
        ParameterInputs = new ObservableCollection<ParameterInputViewModel>();
        
        // Default to searching within selected category
        SearchWithinCategory = true;
        
        // Initialize toggle search scope command
        ToggleSearchScopeCommand = new RelayCommand(ToggleSearchScope);
        
        // Initialize clear search command
        ClearSearchCommand = new RelayCommand(ClearSearch, () => !string.IsNullOrWhiteSpace(SearchText));
        
        // Initialize cancel command
        CancelCommand = new RelayCommand(CancelOperation, () => IsBusy && CancelTokenSource != null && !CancelTokenSource.IsCancellationRequested);
        
        // Initialize focus search command
        FocusSearchCommand = new RelayCommand(FocusSearch);
        
        // Initialize clear output command
        ClearOutputCommand = new RelayCommand(ClearOutput);
        
        // Initialize show help command
        ShowHelpCommand = new RelayCommand(ShowHelp);
        
        // Initialize escape command (handles both clear search and cancel)
        EscapeCommand = new RelayCommand(EscapeKeyPressed);
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
    private ICommand? _toggleSearchScopeCommand;

    [ObservableProperty]
    private ICommand? _clearSearchCommand;

    [ObservableProperty]
    private ICommand? _cancelCommand;

    [ObservableProperty]
    private ICommand? _focusSearchCommand;

    [ObservableProperty]
    private ICommand? _clearOutputCommand;

    [ObservableProperty]
    private ICommand? _showHelpCommand;

    [ObservableProperty]
    private ICommand? _escapeCommand;

    [ObservableProperty]
    private string _outputText = string.Empty;

    [ObservableProperty]
    private string _statusText = string.Empty;

    [ObservableProperty]
    private int _filteredCount;

    [ObservableProperty]
    private bool _isBusy;

    [ObservableProperty]
    private int _progressPercentage;

    [ObservableProperty]
    private CancellationTokenSource? _cancelTokenSource;

    /// <summary>
    /// When true, search is limited to the selected category (unless "All" is selected).
    /// When false, search spans all categories regardless of selection.
    /// </summary>
    public bool SearchWithinCategory
    {
        get => _searchWithinCategory;
        set => SetProperty(ref _searchWithinCategory, value);
    }

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
            (RunCommand as CommunityToolkit.Mvvm.Input.RelayCommand)?.NotifyCanExecuteChanged();
            (RunElevatedCommand as CommunityToolkit.Mvvm.Input.RelayCommand)?.NotifyCanExecuteChanged();
            (CancelCommand as CommunityToolkit.Mvvm.Input.RelayCommand)?.NotifyCanExecuteChanged();
        }

    /// <summary>
    /// Notifies that the cancel command's ability to execute has changed.
    /// </summary>
    private void NotifyCancelCommandChanged()
    {
        (CancelCommand as CommunityToolkit.Mvvm.Input.RelayCommand)?.NotifyCanExecuteChanged();
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
            ToastService.Show($"Refusing to run '{selection.Name}': not in the loaded registry snapshot.", ToastType.Error, _repoRoot);
            return;
        }

        if (!RequiredParametersSatisfied())
        {
            StatusText = $"Fill in the required parameters for '{selection.Name}' first.";
            ToastService.Show($"Fill in the required parameters for '{selection.Name}' first.", ToastType.Warning, _repoRoot);
            return;
        }

        var parameters = CollectParameterValues();
        var stamp = DateTime.Now.ToString("HH:mm:ss");
        StatusText = $"Running '{selection.Name}'...";

        // Set busy state and reset progress
        IsBusy = true;
        ProgressPercentage = 0;
        
        // Setup cancellation token source for this operation
        CancelTokenSource = new CancellationTokenSource();

        try
        {
            var artifacts = Launch(selection.Definition, parameters, elevated, DryRun);
            if (artifacts is null)
            {
                // Interactive console path: no per-run artifacts exist (Start-HubRun parity).
                AppendOutput($"[{stamp}] '{selection.Name}' is an interactive tool - opened it in a separate console window. Use that window; its output cannot be captured here.");
                StatusText = $"Opened '{selection.Name}' in a console window.";
                ToastService.Show($"Opened '{selection.Name}' in a console window.", ToastType.Info, _repoRoot);
                return;
            }

            AppendOutput($"[{stamp}] Launched '{selection.Name}'{(elevated ? " (elevated)" : string.Empty)}{(DryRun ? " (dry run)" : string.Empty)}.");
            _ = PollRunOutputAsync(artifacts);
        }
        catch (OperationCanceledException)
        {
            StatusText = $"Operation cancelled.";
            ToastService.Show("Operation cancelled.", ToastType.Warning, _repoRoot);
        }
        catch (Exception ex)
        {
            StatusText = $"Error running command: {ex.Message}";
            ToastService.Show($"Error running command: {ex.Message}", ToastType.Error, _repoRoot);
        }
        finally
        {
            // Reset busy state when operation completes or fails
            IsBusy = false;
            ProgressPercentage = 0;
            CancelTokenSource = null;
        }
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
        var progress = 0;
        while (true)
        {
            // Check for cancellation
            if (CancelTokenSource?.IsCancellationRequested == true)
            {
                throw new OperationCanceledException();
            }

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
                
                // Show toast based on exit code
                if (int.TryParse(exitLine, out int exitCode) && exitCode == 0)
                {
                    ToastService.Show($"Command '{artifacts.RunId}' completed successfully.", ToastType.Success, _repoRoot);
                }
                else
                {
                    ToastService.Show($"Command '{artifacts.RunId}' failed with exit code: {exitLine}", ToastType.Error, _repoRoot);
                }
                
                // Complete progress
                ProgressPercentage = 100;
                break;
            }

            // Simulate progress (in a real app, this would be based on actual progress)
            progress = (progress + 10) % 90; // Cycle from 0-89 to show activity
            ProgressPercentage = progress;

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

    private async Task ExecuteDebouncedSearch(string searchText, CancellationToken cancellationToken)
    {
        try
        {
            // In production, use debounce; in test environment (UiInvoker null), skip debounce
            if (UiInvoker != null)
            {
                // Wait for the debounce period
                await Task.Delay(SearchDebounceMs, cancellationToken).ConfigureAwait(true);
            }
            
            // If operation wasn't cancelled, update the filter
            if (!cancellationToken.IsCancellationRequested)
            {
                // We need to invoke on UI thread if UiInvoker is set
                if (UiInvoker is { } invoker)
                {
                    invoker(() => ApplyFilter());
                }
                else
                {
                    ApplyFilter();
                }
            }
        }
        catch (TaskCanceledException)
        {
            // This is expected when we cancel for a new search
        }
        catch (Exception ex)
        {
            // Log unexpected errors but don't crash the search
            StatusText = $"Search error: {ex.Message}";
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
        
        // Determine search scope based on SearchWithinCategory setting
        bool searchAllCategories = !SearchWithinCategory || (category?.Name == AllCategory);
        
        if (!searchAllCategories && category is not null && category.Name != AllCategory)
        {
            source = RegistryService.ByCategory(_snapshot, category.Name);
        }

        if (!string.IsNullOrWhiteSpace(SearchText))
        {
            var scoped = new RegistrySnapshot { Commands = source.ToList() };
            source = RegistryService.Search(scoped, SearchText);
        }

        var matches = source.OrderBy(c => c.Name, StringComparer.OrdinalIgnoreCase).ToList();
        var viewModels = matches.Select(d => 
        {
            var vm = new CommandItemViewModel(d);
            // Update highlighted text for search matches
            vm.UpdateHighlightedText(SearchText);
            return vm;
        });
        FilteredCommands = new ObservableCollection<CommandItemViewModel>(viewModels);
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

    partial void OnSearchTextChanged(string value)
    {
        // Cancel any pending debounced search
        _searchDebounceCts?.Cancel();
        
        // Create new cancellation token source for this search
        _searchDebounceCts = new CancellationTokenSource();
        
        // Execute search after debounce delay
        _ = ExecuteDebouncedSearch(value, _searchDebounceCts.Token);
    }

    partial void OnSelectedCommandChanged(CommandItemViewModel? value)
    {
        RebuildParameterInputs();
        OnPropertyChanged(nameof(ShowElevatedButton));
        NotifyRunCommandsChanged();
    }

    private void ToggleSearchScope()
    {
        SearchWithinCategory = !SearchWithinCategory;
        // Reapply filter when scope changes
        ApplyFilter();
    }

    private void CancelOperation()
    {
        if (CancelTokenSource != null && !CancelTokenSource.IsCancellationRequested)
        {
            CancelTokenSource.Cancel();
            StatusText = "Cancelling operation...";
        }
    }

    // --- Settings panel ---------------------------------------------------

    [ObservableProperty]
    private bool settingsVisible;

    [ObservableProperty]
    private string settingsTheme = "dark";

    [ObservableProperty]
    private bool settingsToasts = true;

    [ObservableProperty]
    private bool settingsAutostart;

    [ObservableProperty]
    private bool settingsDefaultDryRun;

    [ObservableProperty]
    private string settingsLogLevel = "info";

    [ObservableProperty]
    private int settingsToastMinSeconds = 10;

    /// <summary>Opens the settings panel pre-filled from config/app-settings.json.</summary>
    [RelayCommand]
    private void ShowSettings()
    {
        var settings = _settingsService.Load(Path.Combine(_repoRoot, "config", "app-settings.json"));
        SettingsTheme = settings.Theme;
        SettingsToasts = settings.Toasts;
        SettingsAutostart = settings.Autostart;
        SettingsDefaultDryRun = settings.DefaultDryRun;
        SettingsLogLevel = settings.LogLevel;
        SettingsToastMinSeconds = settings.ToastMinSeconds;
        SettingsVisible = true;
    }

    /// <summary>Validates and persists the panel values (schema-locked keys/valid sets).</summary>
    [RelayCommand]
    private void SaveSettings()
    {
        if (!SettingsService.ValidThemes.Contains(SettingsTheme, StringComparer.OrdinalIgnoreCase))
        {
            StatusText = $"Invalid theme '{SettingsTheme}' - not saved.";
            return;
        }

        if (!SettingsService.ValidLogLevels.Contains(SettingsLogLevel, StringComparer.OrdinalIgnoreCase))
        {
            StatusText = $"Invalid log level '{SettingsLogLevel}' - not saved.";
            return;
        }

        var settings = new AppSettings
        {
            Theme = SettingsTheme.Trim().ToLowerInvariant(),
            Toasts = SettingsToasts,
            Autostart = SettingsAutostart,
            DefaultDryRun = SettingsDefaultDryRun,
            LogLevel = SettingsLogLevel.Trim().ToLowerInvariant(),
            ToastMinSeconds = SettingsToastMinSeconds,
        };
        _settingsService.Save(Path.Combine(_repoRoot, "config", "app-settings.json"), settings);
        DryRun = settings.DefaultDryRun;
        SettingsVisible = false;
        StatusText = "Settings saved.";
    }

    [RelayCommand]
    private void CancelSettings() => SettingsVisible = false;

    private void ClearSearch()
    {
        SearchText = string.Empty;
    }

    private void FocusSearch()
    {
        // Focus the search textbox - in a real implementation, we would use UiInvoker or similar
        // For now, we'll just set focus through the view if possible
        // This is a placeholder - actual focus would need to be handled in the view
    }

    private void ClearOutput()
    {
        OutputText = string.Empty;
    }

    private void ShowHelp()
    {
        // Show help dialog or documentation
        // This would typically open a help window or navigate to documentation
        StatusText = "Help functionality would be implemented here.";
    }

    private void EscapeKeyPressed()
    {
        if (IsBusy && CancelTokenSource != null && !CancelTokenSource.IsCancellationRequested)
        {
            // If busy, cancel the operation
            CancelOperation();
        }
        else if (!string.IsNullOrWhiteSpace(SearchText))
        {
            // If search text exists, clear it
            ClearSearch();
        }
        // Otherwise do nothing
    }
}
