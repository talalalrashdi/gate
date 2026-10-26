namespace CompanyPortal.Api.Contracts;

// ColorValue 1-4 maps to Color green/yellow/orange/red. LastUpdated is the SQL datetime
// as a local ISO value (no timezone), matching how the status owner records it.
public sealed record OrganizationStatus(int ColorValue,string Color,string LastUpdated,int? No);
