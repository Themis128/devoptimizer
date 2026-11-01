using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using DevOptimizer.App.Models;
using DevOptimizer.App.UserControls;

namespace DevOptimizer.App.Services
{
    /// <summary>
    /// Service for displaying toast notifications in the application.
    /// Respects user settings for toast enabled/disabled and minimum display time.
    /// </summary>
    public static class ToastService
    {
        /// <summary>
        /// Shows a toast notification.
        /// </summary>
        /// <param name="message">The message to display.</param>
        /// <param name="type">The type of toast (Info, Success, Warning, Error).</param>
        /// <param name="repositoryRoot">The repository root path (used to load settings).</param>
        /// <param name="displaySeconds">Optional override for display duration in seconds.</param>
        /// <summary>
    /// Pure settings decision for a toast: whether it should show and for how long.
    /// Extracted from Show so the policy is unit-testable without a WPF context.
    /// </summary>
    public static ToastDecision Resolve(string message, ToastType type, string? repositoryRoot, int? displaySeconds)
    {
        bool showToast = true;
        int secondsToDisplay = 5; // Default

        if (!string.IsNullOrEmpty(repositoryRoot))
        {
            try
            {
                var settingsFile = System.IO.Path.Combine(repositoryRoot, "config", "app-settings.json");
                if (System.IO.File.Exists(settingsFile))
                {
                    var json = System.IO.File.ReadAllText(settingsFile);
                    var settings = System.Text.Json.JsonSerializer.Deserialize<AppSettings>(json);
                    if (settings != null)
                    {
                        showToast = settings.Toasts;
                        secondsToDisplay = Math.Max(settings.ToastMinSeconds, 1); // Minimum 1 second
                    }
                }
            }
            catch (Exception)
            {
                // If we can't read settings, default to showing toast
            }
        }

        // Override display seconds if provided
        if (displaySeconds.HasValue && displaySeconds.Value > 0)
        {
            secondsToDisplay = displaySeconds.Value;
        }

        return new ToastDecision(showToast, secondsToDisplay);
    }

    public sealed record ToastDecision(bool Show, int Seconds);

    public static void Show(string message,
                               ToastType type = ToastType.Info,
                               string? repositoryRoot = null,
                               int? displaySeconds = null)
        {
            var decision = Resolve(message, type, repositoryRoot, displaySeconds);
            if (!decision.Show)
            {
                return;
            }

            // Get the main window to add toast to
            if (Application.Current == null || Application.Current.MainWindow == null)
                return;

            var mainWindow = Application.Current.MainWindow as Views.MainWindow;
            if (mainWindow == null)
                return;

            // Create toast
            var toast = new Toast
            {
                Type = type,
                Message = message
            };

            if (displaySeconds.HasValue)
            {
                toast.DisplaySeconds = displaySeconds.Value;
            }
            else if (!string.IsNullOrEmpty(repositoryRoot))
            {
                // Use settings-based duration
                toast.DisplaySeconds = decision.Seconds;
            }

            // Add to toast container (we'll need to add this to MainWindow)
            // For now, we'll add to a grid that we'll create in MainWindow
            Application.Current.Dispatcher.Invoke(() =>
            {
                // Find or create toast container
                var toastContainer = FindToastContainer(mainWindow);
                if (toastContainer != null)
                {
                    // Add toast to container
                    toastContainer.Children.Add(toast);
                    
                    // Position toast (stack from bottom-right)
                    PositionToasts(toastContainer);
                }
            });
        }

        private static Panel? FindToastContainer(Window window)
        {
            // Look for a container with name "ToastContainer"
            if (window is FrameworkElement frameworkElement)
            {
                var container = frameworkElement.FindName("ToastContainer") as Panel;
                if (container != null)
                    return container;
                
                // Search recursively
                return FindToastContainerRecursive(frameworkElement);
            }
            return null;
        }

        private static Panel? FindToastContainerRecursive(FrameworkElement element)
        {
            int childrenCount = VisualTreeHelper.GetChildrenCount(element);
            for (int i = 0; i < childrenCount; i++)
            {
                var child = VisualTreeHelper.GetChild(element, i);
                if (child is FrameworkElement fe)
                {
                    if (fe.Name == "ToastContainer")
                    {
                        return fe as Panel;
                    }
                    
                    var result = FindToastContainerRecursive(fe);
                    if (result != null)
                        return result;
                }
            }
            return null;
        }

        private static void PositionToasts(Panel container)
        {
            if (container == null) return;
            
            double yOffset = 10; // Start 10px from bottom
            double spacing = 10; // Space between toasts
            
            // Position from bottom-right, stacking upward
            for (int i = container.Children.Count - 1; i >= 0; i--)
            {
                if (container.Children[i] is FrameworkElement toast)
                {
                    // Set position
                    Canvas.SetLeft(toast, container.ActualWidth - toast.ActualWidth - 10);
                    Canvas.SetTop(toast, container.ActualHeight - yOffset - toast.ActualHeight);
                    
                    yOffset += toast.ActualHeight + spacing;
                }
            }
        }
    }
}