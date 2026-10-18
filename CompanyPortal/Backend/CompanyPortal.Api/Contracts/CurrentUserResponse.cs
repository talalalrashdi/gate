namespace CompanyPortal.Api.Contracts;

public sealed record CurrentUserResponse(
    string AccountName,
    string? Sid,
    string? AuthenticationType);
