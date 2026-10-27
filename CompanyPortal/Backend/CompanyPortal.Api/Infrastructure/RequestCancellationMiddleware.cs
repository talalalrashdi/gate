namespace CompanyPortal.Api.Infrastructure;

/// <summary>Expected client disconnects must not become application failures.</summary>
public sealed class RequestCancellationMiddleware(RequestDelegate next,ILogger<RequestCancellationMiddleware> logger)
{
    public async Task InvokeAsync(HttpContext context)
    {
        try{await next(context);}
        catch(OperationCanceledException) when(context.RequestAborted.IsCancellationRequested)
        {
            // The browser has gone away; do not write an error body to that connection.
            if(!context.Response.HasStarted)context.Response.StatusCode=499;
            logger.LogDebug("Client canceled {Method} {Path}; trace {TraceId}.",context.Request.Method,context.Request.Path,context.TraceIdentifier);
        }
    }
}
