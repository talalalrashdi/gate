namespace CompanyPortal.Api.Contracts;

// String ID preserves the full SQL bigint range in JavaScript. Dates are
// date-only ISO values, with no timezone/calendar conversion inferred.
public sealed record FixedOrder(string FixedOrderId,string? Timestamp,string? Timestamp2,
    string? ContentBefor,string? ContentAfter,string? ContentText,int TimestampType,int? Year);
