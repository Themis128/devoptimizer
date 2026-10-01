using System.Windows;
using DevOptimizer.App.Services;
using DevOptimizer.App.ViewModels;

namespace DevOptimizer.App.Views;

/// <summary>
/// Wiring-only code-behind: receives the ViewModel from DI and hands it to the view.
/// All behavior lives in MainViewModel (unit-tested); enforced by a hygiene test that
/// asserts no runtime XAML parsing and no method body over 10 lines.
/// </summary>
public partial class MainWindow : Window
{
    public MainWindow(MainViewModel viewModel)
    {
        InitializeComponent();
        ViewModel = viewModel;
        DataContext = ViewModel;
        ViewModel.UiInvoker = action => Dispatcher.Invoke(action);
        Loaded += OnLoaded;
    }

    public MainViewModel ViewModel { get; }

    private async void OnLoaded(object sender, RoutedEventArgs e) => await ViewModel.LoadAsync();

    /// <summary>Selftest hook: registry-driven checks against the bound ViewModel and this window's visual structure.</summary>
    public IReadOnlyList<SelfTestCheck> RunSelfTestChecks(string repoRoot) =>
        SelfTestRunner.RunChecks(ViewModel, repoRoot, SelfTestRunner.SelfTestQuery, SelfTestRunner.CountDetailPanelChildren(this));
}
