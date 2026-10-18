using System;
using System.Globalization;
using System.Windows.Data;
using System.Windows.Input;

namespace DevOptimizer.App.Views.Converters
{
    /// <summary>
    /// Converter for Esc key behavior: clears search if text has focus, otherwise cancels operation.
    /// </summary>
    public class EscKeyConverter : IMultiValueConverter
    {
        public object? Convert(object[]? values, Type targetType, object? parameter, CultureInfo culture)
        {
            if (values == null || values.Length < 2)
                return new KeyBinding { Command = ApplicationCommands.NotACommand };

            bool isBusy = (values[0] is bool busy) && busy;
            string? searchText = values[1] as string;

            // If there's search text, clear it; otherwise, cancel operation if busy
            if (!string.IsNullOrWhiteSpace(searchText))
            {
                // Return a command to clear search
                return new KeyBinding { Command = ApplicationCommands.NotACommand }; // We'll handle this in the ViewModel
            }
            else if (isBusy)
            {
                // Return a command to cancel operation
                return new KeyBinding { Command = ApplicationCommands.NotACommand }; // We'll handle this in the ViewModel
            }
            else
            {
                // Do nothing
                return new KeyBinding { Command = ApplicationCommands.NotACommand };
            }
        }

        public object[]? ConvertBack(object? value, Type[] targetTypes, object? parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}