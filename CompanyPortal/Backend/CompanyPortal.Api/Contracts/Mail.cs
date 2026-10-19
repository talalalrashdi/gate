namespace CompanyPortal.Api.Contracts;

public sealed record InboxMessage(string ItemId, string Subject, string Sender, DateTimeOffset ReceivedAt, bool IsRead);
public sealed record InboxSnapshot(int UnreadCount, IReadOnlyList<InboxMessage> Items, DateTimeOffset UpdatedAt);
