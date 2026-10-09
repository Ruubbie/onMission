using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace Missie.Desktop.Views.Shared;

public partial class StatTile : UserControl
{
    public static readonly DependencyProperty LabelProperty = DependencyProperty.Register(nameof(Label), typeof(string), typeof(StatTile));
    public static readonly DependencyProperty ValueProperty = DependencyProperty.Register(nameof(Value), typeof(string), typeof(StatTile));
    public static readonly DependencyProperty SubProperty = DependencyProperty.Register(nameof(Sub), typeof(string), typeof(StatTile));
    public static readonly DependencyProperty AccentProperty =
        DependencyProperty.Register(nameof(Accent), typeof(Brush), typeof(StatTile), new PropertyMetadata(Brushes.White));

    public StatTile() => InitializeComponent();

    public string? Label { get => (string?)GetValue(LabelProperty); set => SetValue(LabelProperty, value); }
    public string? Value { get => (string?)GetValue(ValueProperty); set => SetValue(ValueProperty, value); }
    public string? Sub { get => (string?)GetValue(SubProperty); set => SetValue(SubProperty, value); }
    public Brush? Accent { get => (Brush?)GetValue(AccentProperty); set => SetValue(AccentProperty, value); }
}
