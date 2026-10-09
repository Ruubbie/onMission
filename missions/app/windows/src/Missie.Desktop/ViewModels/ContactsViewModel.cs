using Missie.Core;
using Missie.Desktop.Views.Shared;

namespace Missie.Desktop.ViewModels;

public sealed class ContactRow : EntityRow<Contact>
{
    public ContactRow(Contact c, Action<Entity> save) : base(c, save) { }

    public string Name { get => Model.Name; set => Set(Model.Name, value ?? "", v => Model.Name = v); }
    public string? Role { get => Model.Role; set => Set(Model.Role, Fmt.Opt(value), v => Model.Role = v); }
    public string? Organisation { get => Model.Organisation; set => Set(Model.Organisation, Fmt.Opt(value), v => Model.Organisation = v); }
    public string? Email { get => Model.Email; set => Set(Model.Email, Fmt.Opt(value), v => Model.Email = v); }
    public string? Phone { get => Model.Phone; set => Set(Model.Phone, Fmt.Opt(value), v => Model.Phone = v); }
    public string? Address { get => Model.Address; set => Set(Model.Address, Fmt.Opt(value), v => Model.Address = v); }
    public string? Notes { get => Model.Notes; set => Set(Model.Notes, Fmt.Opt(value), v => Model.Notes = v); }
}

public sealed class ContactsViewModel : EntityListViewModel<Contact, ContactRow>
{
    string _subtitle = "";
    public string Subtitle { get => _subtitle; private set => SetProperty(ref _subtitle, value); }

    protected override ContactRow CreateRow(Contact c) => new(c, SaveEntity);
    protected override string SearchText(ContactRow r) =>
        $"{r.Model.Name} {r.Model.Role} {r.Model.Organisation} {r.Model.Email} {r.Model.Phone} {r.Model.Address} {r.Model.Notes}";

    protected override void Recompute()
    {
        int orgs = Rows.Select(r => r.Model.Organisation).Where(o => !string.IsNullOrWhiteSpace(o)).Distinct(StringComparer.OrdinalIgnoreCase).Count();
        Subtitle = $"{Rows.Count} contact{(Rows.Count == 1 ? "" : "s")} · {orgs} organisation{(orgs == 1 ? "" : "s")} (YWAM, immigration, church, insurer…)";
    }

    public ContactRow New() => Add(new Contact { Name = "New contact" });
}
