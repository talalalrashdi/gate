namespace CompanyPortal.Api.Contracts;

public sealed record CalendarAccess(bool Read,bool Create,bool Modify,bool Delete,bool ViewPrivateItems);
public sealed record ScheduleCalendar(string Key,string Name,bool IsOwn,bool LiveUpdates,CalendarAccess Rights);
public sealed record ScheduleCatalog(string TimeZone,IReadOnlyList<ScheduleCalendar> Calendars);
public sealed record CalendarAppointment(string ItemId,string Subject,DateTimeOffset Start,DateTimeOffset End,bool IsAllDay,
    string Location,string Organizer,bool IsCancelled,bool IsPrivate,string ResponseStatus);
public sealed record ExchangeTask(string ItemId,string Subject,string? DueDate,string? StartDate,string Status,string Importance,double PercentComplete);
public sealed record CalendarResult(IReadOnlyList<CalendarAppointment> Items,bool Truncated);
public sealed record TaskResult(IReadOnlyList<ExchangeTask> Items,bool Truncated);
public sealed record ScheduleSnapshot(string CalendarKey,string CalendarName,string TimeZone,bool CalendarLive,DateOnly From,DateOnly To,
    CalendarResult Calendar,TaskResult Tasks,DateTimeOffset UpdatedAt);
