using Microsoft.EntityFrameworkCore;

namespace SchoolAdmission.Api;

/// <summary>Marks overdue HELD holds as EXPIRED so seats free themselves with no API call.
/// Correctness never depends on this: every query also treats overdue HELD rows as expired.</summary>
public class ExpirySweeper(IServiceProvider sp, ILogger<ExpirySweeper> log) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                using var scope = sp.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDb>();
                var now = DateTime.UtcNow;
                await db.Holds.Where(h => h.Status == "HELD" && h.ExpiresAt <= now)
                    .ExecuteUpdateAsync(s => s.SetProperty(h => h.Status, "EXPIRED"), ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                log.LogWarning(ex, "Expiry sweep failed");
            }
            try { await Task.Delay(TimeSpan.FromSeconds(1), ct); } catch (OperationCanceledException) { }
        }
    }
}
