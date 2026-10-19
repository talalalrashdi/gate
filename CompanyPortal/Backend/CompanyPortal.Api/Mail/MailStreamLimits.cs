namespace CompanyPortal.Api.Mail;

// Bound long-lived subscriptions. A browser tab owns its subscription and releases
// it on disconnect; no background worker monitors mailboxes after users leave.
public sealed class MailStreamLimits
{
    private readonly Dictionary<string, int> accounts = new(StringComparer.OrdinalIgnoreCase);
    private int total;
    public IDisposable? TryEnter(string account)
    {
        lock (accounts)
        {
            var count = accounts.GetValueOrDefault(account);
            if (count >= 2 || total >= 100) return null;
            accounts[account] = count + 1; total++;
            return new Lease(() => { lock (accounts) { if (--accounts[account] == 0) accounts.Remove(account); total--; } });
        }
    }
    private sealed class Lease(Action release) : IDisposable
    {
        private Action? action = release;
        public void Dispose() => Interlocked.Exchange(ref action, null)?.Invoke();
    }
}
