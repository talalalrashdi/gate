namespace CompanyPortal.Api.Mail;

// Bound long-lived subscriptions. A browser tab owns its subscription and releases
// it on disconnect; no background worker monitors mailboxes after users leave.
public sealed class MailStreamLimits(IConfiguration? configuration = null)
{
    private readonly Dictionary<string, int> accounts = new(StringComparer.OrdinalIgnoreCase);
    private int total;
    public IDisposable? TryEnter(string account)
    {
        lock (accounts)
        {
            var count = accounts.GetValueOrDefault(account);
            var perAccount=Math.Clamp(configuration?.GetValue<int>("Exchange:MaximumStreamsPerAccount",4)??2,1,12);
            var maximum=Math.Clamp(configuration?.GetValue<int>("Exchange:MaximumStreams",100)??100,1,1000);
            if (count >= perAccount || total >= maximum) return null;
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
