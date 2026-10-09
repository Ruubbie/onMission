using Missie.Core;

namespace Missie.Desktop;

/// <summary>Page keys used by the sidebar and by smart links.</summary>
public static class Pages
{
    public const string Home = "home";
    public const string Checklists = "checklists";
    public const string Partners = "partners";
    public const string Budget = "budget";
    public const string Documents = "documents";
    public const string Newsletter = "newsletter";
    public const string Notes = "notes";
    public const string Packing = "packing";
    public const string Selling = "selling";
    public const string Contacts = "contacts";
    public const string Settings = "settings";
}

public interface INavigator
{
    void Go(string pageKey);
    /// <summary>Smart link: opens the page for this entity's type and selects it.</summary>
    void Open(string entityId);
}

/// <summary>Pages that can select a specific entity when opened through a smart link implement this.</summary>
public interface ISelectsEntity
{
    void Select(string entityId);
}

/// <summary>Pages that can create a new item (Ctrl+N) implement this.</summary>
public interface ICreatesItems
{
    void CreateNew();
}
