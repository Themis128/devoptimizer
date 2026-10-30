using System;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;

namespace DevOptimizer.App.UserControls
{
    public enum ToastType
    {
        Info,
        Success,
        Warning,
        Error
    }

    public partial class Toast : UserControl
    {
        private readonly DispatcherTimer _autoCloseTimer;

        public Toast()
        {
            InitializeComponent();
            
            // Setup auto-close timer
            _autoCloseTimer = new DispatcherTimer();
            _autoCloseTimer.Interval = TimeSpan.FromSeconds(5); // Default 5 seconds
            _autoCloseTimer.Tick += AutoCloseTimer_Tick;
            
            // Setup animations
            Loaded += Toast_Loaded;
            Unloaded += Toast_Unloaded;
            
            // Setup close button
            CloseButton.Click += CloseButton_Click;
        }

        public ToastType Type
        {
            set
            {
                switch (value)
                {
                    case ToastType.Info:
                        IconText.Text = "&#xE896;"; // Info icon
                        ToastBorder.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#0078D4"));
                        break;
                    case ToastType.Success:
                        IconText.Text = "&#xE73E;"; // Success icon
                        ToastBorder.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#107C10"));
                        break;
                    case ToastType.Warning:
                        IconText.Text = "&#xE7BA;"; // Warning icon
                        ToastBorder.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#FF8C00"));
                        break;
                    case ToastType.Error:
                        IconText.Text = "&#xE783;"; // Error icon
                        ToastBorder.Background = new SolidColorBrush((Color)ColorConverter.ConvertFromString("#D13438"));
                        break;
                }
            }
        }

        public string Message
        {
            set => MessageText.Text = value;
        }

        public int DisplaySeconds
        {
            set => _autoCloseTimer.Interval = TimeSpan.FromSeconds(value);
        }

        private void Toast_Loaded(object sender, RoutedEventArgs e)
        {
            // Start fade-in animation
            var storyboard = (Storyboard)Resources["FadeInStoryboard"];
            storyboard.Begin();
            
            // Start auto-close timer
            _autoCloseTimer.Start();
        }

        private void Toast_Unloaded(object sender, RoutedEventArgs e)
        {
            _autoCloseTimer.Stop();
        }

        private void AutoCloseTimer_Tick(object? sender, EventArgs e)
        {
            _autoCloseTimer.Stop();
            CloseToast();
        }

        private void CloseButton_Click(object sender, RoutedEventArgs e)
        {
            CloseToast();
        }

        private void CloseToast()
        {
            // Start fade-out animation
            var storyboard = (Storyboard)Resources["FadeOutStoryboard"];
            storyboard.Completed += (s, args) =>
            {
                if (Parent is Panel panel)
                {
                    panel.Children.Remove(this);
                }
            };
            storyboard.Begin();
        }
    }
}