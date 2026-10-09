using System.Collections;
using System.Windows;
using System.Windows.Controls;

namespace Missie.Desktop.Views.Shared;

public partial class ChipBar : UserControl
{
    public static readonly DependencyProperty ItemsSourceProperty =
        DependencyProperty.Register(nameof(ItemsSource), typeof(IEnumerable), typeof(ChipBar));

    public ChipBar() => InitializeComponent();

    public IEnumerable? ItemsSource
    {
        get => (IEnumerable?)GetValue(ItemsSourceProperty);
        set => SetValue(ItemsSourceProperty, value);
    }

    /// <summary>Raised with the clicked FilterChip.</summary>
    public event EventHandler<FilterChip>? ChipClicked;

    void Chip_Click(object sender, RoutedEventArgs e)
    {
        if ((sender as FrameworkElement)?.DataContext is FilterChip chip) ChipClicked?.Invoke(this, chip);
    }
}
