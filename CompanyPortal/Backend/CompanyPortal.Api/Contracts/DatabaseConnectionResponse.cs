namespace CompanyPortal.Api.Contracts;

public sealed record DatabaseConnectionResponse(
    string Status,
    string DatabaseName,
    DateTimeOffset CheckedAtUtc);
