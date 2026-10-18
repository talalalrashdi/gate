namespace CompanyPortal.Web.Models;

public sealed record ConnectionCheckViewModel(
    bool ApiConnected,
    bool DatabaseConnected,
    string? DatabaseName,
    DateTimeOffset? CheckedAtUtc,
    string? Error);

// Kept local so the frontend solution builds without a project reference to the API.
public sealed record DatabaseConnectionResponse(
    string Status,
    string DatabaseName,
    DateTimeOffset CheckedAtUtc);
