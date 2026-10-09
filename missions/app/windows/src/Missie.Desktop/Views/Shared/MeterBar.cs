using System.Globalization;
using System.Windows;
using System.Windows.Media;

namespace Missie.Desktop.Views.Shared;

/// <summary>
/// A chunky progress bar: thick outline, flat fill, hard shadow, and up to two labelled marker lines
/// (e.g. minimum and target support, or a bag's weight limit). Fill turns OverFill when Value passes Limit.
/// </summary>
public sealed class MeterBar : FrameworkElement
{
    public static readonly DependencyProperty ValueProperty = Reg(nameof(Value), 0.0);
    public static readonly DependencyProperty MaximumProperty = Reg(nameof(Maximum), 1.0);
    public static readonly DependencyProperty Marker1Property = Reg(nameof(Marker1), double.NaN);
    public static readonly DependencyProperty Marker2Property = Reg(nameof(Marker2), double.NaN);
    public static readonly DependencyProperty Marker1LabelProperty = Reg(nameof(Marker1Label), (string?)null);
    public static readonly DependencyProperty Marker2LabelProperty = Reg(nameof(Marker2Label), (string?)null);
    /// <summary>When Value exceeds this, OverFill is used (NaN = never).</summary>
    public static readonly DependencyProperty LimitProperty = Reg(nameof(Limit), double.NaN);
    public static readonly DependencyProperty FillProperty = Reg(nameof(Fill), (Brush?)null);
    public static readonly DependencyProperty OverFillProperty = Reg(nameof(OverFill), (Brush?)null);
    public static readonly DependencyProperty BarHeightProperty = Reg(nameof(BarHeight), 30.0);

    static DependencyProperty Reg<TV>(string name, TV def) =>
        DependencyProperty.Register(name, typeof(TV), typeof(MeterBar),
            new FrameworkPropertyMetadata(def, FrameworkPropertyMetadataOptions.AffectsRender | FrameworkPropertyMetadataOptions.AffectsMeasure));

    public double Value { get => (double)GetValue(ValueProperty); set => SetValue(ValueProperty, value); }
    public double Maximum { get => (double)GetValue(MaximumProperty); set => SetValue(MaximumProperty, value); }
    public double Marker1 { get => (double)GetValue(Marker1Property); set => SetValue(Marker1Property, value); }
    public double Marker2 { get => (double)GetValue(Marker2Property); set => SetValue(Marker2Property, value); }
    public string? Marker1Label { get => (string?)GetValue(Marker1LabelProperty); set => SetValue(Marker1LabelProperty, value); }
    public string? Marker2Label { get => (string?)GetValue(Marker2LabelProperty); set => SetValue(Marker2LabelProperty, value); }
    public double Limit { get => (double)GetValue(LimitProperty); set => SetValue(LimitProperty, value); }
    public Brush? Fill { get => (Brush?)GetValue(FillProperty); set => SetValue(FillProperty, value); }
    public Brush? OverFill { get => (Brush?)GetValue(OverFillProperty); set => SetValue(OverFillProperty, value); }
    public double BarHeight { get => (double)GetValue(BarHeightProperty); set => SetValue(BarHeightProperty, value); }

    bool HasLabels => !string.IsNullOrEmpty(Marker1Label) || !string.IsNullOrEmpty(Marker2Label);
    const double Shadow = 5, LabelBand = 20;

    protected override Size MeasureOverride(Size available) =>
        new(double.IsInfinity(available.Width) ? 300 : available.Width, BarHeight + Shadow + (HasLabels ? LabelBand : 0));

    protected override void OnRender(DrawingContext dc)
    {
        var ink = Palette.Get("Ink");
        var paper = Palette.Get("Paper");
        double top = HasLabels ? LabelBand : 0;
        double w = Math.Max(0, ActualWidth - Shadow), h = BarHeight;
        var bar = new Rect(0, top, w, h);
        var pen = new Pen(ink, 3);

        dc.DrawRoundedRectangle(ink, null, new Rect(Shadow, top + Shadow, w, h), 8, 8);
        dc.DrawRoundedRectangle(paper, null, bar, 8, 8);

        double max = Maximum > 0 ? Maximum : 1;
        double frac = Math.Clamp(Value / max, 0, 1);
        bool over = !double.IsNaN(Limit) && Value > Limit;
        var fill = over ? (OverFill ?? Palette.Get("Pink")) : (Fill ?? Palette.Get("Green"));
        if (frac > 0)
        {
            dc.PushClip(new RectangleGeometry(bar, 8, 8));
            dc.DrawRectangle(fill, null, new Rect(0, top, w * frac, h));
            dc.Pop();
        }
        dc.DrawRoundedRectangle(null, pen, bar, 8, 8);

        DrawMarker(dc, Marker1, Marker1Label, max, w, top, h, ink, alignRight: true);
        DrawMarker(dc, Marker2, Marker2Label, max, w, top, h, ink, alignRight: false);
    }

    void DrawMarker(DrawingContext dc, double at, string? label, double max, double w, double top, double h, Brush ink, bool alignRight)
    {
        if (double.IsNaN(at) || at <= 0) return;
        double x = Math.Clamp(at / max, 0, 1) * w;
        dc.DrawLine(new Pen(ink, 3) { DashStyle = DashStyles.Dash }, new Point(x, top - 4), new Point(x, top + h + 2));
        if (string.IsNullOrEmpty(label)) return;
        var ft = new FormattedText(label, CultureInfo.CurrentUICulture, FlowDirection.LeftToRight,
            new Typeface(new FontFamily("Segoe UI"), FontStyles.Normal, FontWeights.Bold, FontStretches.Normal),
            12, ink, VisualTreeHelper.GetDpi(this).PixelsPerDip);
        double tx = alignRight ? x - ft.Width - 4 : x + 4;
        tx = Math.Clamp(tx, 0, Math.Max(0, w - ft.Width));
        dc.DrawText(ft, new Point(tx, top - LabelBand + 2));
    }
}
