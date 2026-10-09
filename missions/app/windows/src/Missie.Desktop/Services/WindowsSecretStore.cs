using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Missie.Core;

namespace Missie.Desktop.Services;

/// <summary>ISecretStore backed by Windows DPAPI (CurrentUser scope): only this Windows account can decrypt
/// %LOCALAPPDATA%\Missie\secrets.dat.</summary>
public sealed class WindowsSecretStore : ISecretStore
{
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("Missie.SecretStore.v1");
    private readonly string _path;
    private readonly object _gate = new();
    private Dictionary<string, string>? _cache;

    public WindowsSecretStore(string? path = null)
    {
        _path = path ?? Path.Combine(AppServices.DataDir, "secrets.dat");
    }

    public string? Get(string key)
    {
        lock (_gate) return Load().TryGetValue(key, out var v) ? v : null;
    }

    public void Set(string key, string? value)
    {
        lock (_gate)
        {
            var map = Load();
            if (value is null) map.Remove(key); else map[key] = value;
            var json = JsonSerializer.SerializeToUtf8Bytes(map);
            var blob = ProtectedData.Protect(json, Entropy, DataProtectionScope.CurrentUser);
            Directory.CreateDirectory(Path.GetDirectoryName(_path)!);
            var tmp = _path + ".tmp";
            File.WriteAllBytes(tmp, blob);
            File.Move(tmp, _path, overwrite: true);
        }
    }

    private Dictionary<string, string> Load()
    {
        if (_cache is not null) return _cache;
        _cache = new Dictionary<string, string>();
        try
        {
            if (File.Exists(_path))
            {
                var json = ProtectedData.Unprotect(File.ReadAllBytes(_path), Entropy, DataProtectionScope.CurrentUser);
                _cache = JsonSerializer.Deserialize<Dictionary<string, string>>(json) ?? new();
            }
        }
        catch (Exception ex)
        {
            // Unreadable (other user / corrupted): start empty; the user simply logs in again.
            AppLog.Write("Secret store unreadable, starting empty", ex);
        }
        return _cache;
    }
}
