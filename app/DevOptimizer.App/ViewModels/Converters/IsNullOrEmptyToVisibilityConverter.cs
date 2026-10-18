using System;
using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace DevOptimizer.App.Views.Converters
{
    /// <summary>
    /// Converts string values to Visibility. Returns Visible if string is null or empty, otherwise Collapsed.
    /// </summary>
    public class IsNullOrEmptyToVisibilityConverter : IValueConverter
    {
        public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        {
            if (value is string str)
            {
                return string.IsNullOrWhiteSpace(str) ? Visibility.Visible : Visibility.Collapsed;
            }
            return Visibility.Collapsed;
        }

        public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}