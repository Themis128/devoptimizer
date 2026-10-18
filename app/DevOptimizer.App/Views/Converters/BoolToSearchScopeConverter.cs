using System;
using System.Globalization;
using System.Windows.Data;

namespace DevOptimizer.App.Views.Converters;

/// <summary>
/// Converts boolean values to strings representing search scope.
/// True = "Current Category", False = "All Categories"
/// </summary>
public class BoolToSearchScopeConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
    {
        if (value is bool isWithinCategory)
        {
            return isWithinCategory ? "Current Category" : "All Categories";
        }
        return "All Categories";
    }

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
    {
        throw new NotImplementedException();
    }
}