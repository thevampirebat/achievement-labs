using Avalonia.Controls;
using Avalonia.LogicalTree;

namespace AchievementLabs.MultiSelect;

public static class SearchClearButtons
{
    public static void Attach(Window owner)
    {
        foreach (var box in owner.GetLogicalDescendants().OfType<TextBox>())
        {
            var hint = box.GetType().GetProperty("PlaceholderText")?.GetValue(box)?.ToString()
                ?? box.GetType().GetProperty("Watermark")?.GetValue(box)?.ToString() ?? "";
            if (!hint.Contains("search", StringComparison.OrdinalIgnoreCase) &&
                !hint.Contains("filter", StringComparison.OrdinalIgnoreCase) && hint != "Gamertag") continue;
            var slot = box.GetType().GetProperty("InnerRightContent");
            if (slot?.CanWrite != true || slot.GetValue(box) != null) continue;
            var clear = new Button { Name = "ClearSearch", Content = "×", Width = 28, Height = 28,
                Padding = new Avalonia.Thickness(0), Margin = new Avalonia.Thickness(0, 0, 4, 0),
                IsVisible = !string.IsNullOrEmpty(box.Text) };
            ToolTip.SetTip(clear, "Clear search");
            clear.Click += (_, _) => { box.Text = ""; box.Focus(); };
            box.TextChanged += (_, _) => clear.IsVisible = !string.IsNullOrEmpty(box.Text);
            slot.SetValue(box, clear);
        }
    }
}
