using System;
using System.Globalization;
using System.Text.RegularExpressions;
using System.Windows;
using System.Windows.Data;
using System.Windows.Documents;
using System.Windows.Media;

namespace DevOptimizer.App.Views.Converters
{
    /// <summary>
    /// Converts plain text with highlight markers (<Highlight>text</Highlight>) to a formatted TextBlock.
    /// </summary>
    public class SearchHighlightConverter : IValueConverter
    {
        public object? Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            if (value is not string text)
                return string.Empty;

            // If no highlight markers, return plain text
            if (!text.Contains("<Highlight>") || !text.Contains("</Highlight>"))
                return text;

            try
            {
                // Create a TextBlock with runs for highlighted and normal text
                var textBlock = new System.Windows.Controls.TextBlock();
                
                // Process the text to extract highlighted and normal parts
                var pattern = @"<Highlight>(.*?)</Highlight>";
                var matches = Regex.Matches(text, pattern, RegexOptions.Singleline);
                
                int lastEnd = 0;
                foreach (Match match in matches)
                {
                    // Add normal text before the highlight
                    if (match.Index > lastEnd)
                    {
                        var normalText = text.Substring(lastEnd, match.Index - lastEnd);
                        textBlock.Inlines.Add(new Run(normalText));
                    }
                    
                    // Add highlighted text
                    var highlightedText = match.Groups[1].Value;
                    textBlock.Inlines.Add(new Run(highlightedText)
                    {
                        FontWeight = FontWeights.SemiBold,
                        Background = System.Windows.Media.Brushes.Yellow,
                        Foreground = System.Windows.Media.Brushes.Black
                    });
                    
                    lastEnd = match.Index + match.Length;
                }
                
                // Add remaining text after the last highlight
                if (lastEnd < text.Length)
                {
                    var remainingText = text.Substring(lastEnd);
                    textBlock.Inlines.Add(new Run(remainingText));
                }
                
                return textBlock;
            }
            catch
            {
                // If anything goes wrong, return plain text
                return text;
            }
        }

        public object? ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
        {
            throw new NotImplementedException();
        }
    }
}