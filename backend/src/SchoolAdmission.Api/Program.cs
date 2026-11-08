using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using SchoolAdmission.Api;

var builder = WebApplication.CreateBuilder(args);

// Render sets PORT; locally the default is 8080 (ASPNETCORE_URLS in the Dockerfile).
var port = Environment.GetEnvironmentVariable("PORT");
if (!string.IsNullOrEmpty(port)) builder.WebHost.UseUrls($"http://+:{port}");

builder.Services.AddDbContext<AppDb>(o => o.UseNpgsql(ConnectionString(builder.Configuration)));
builder.Services.AddHostedService<ExpirySweeper>();

var origins = (Environment.GetEnvironmentVariable("CORS_ORIGINS") ?? "*")
    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
builder.Services.AddCors(o => o.AddDefaultPolicy(p =>
{
    if (origins.Contains("*")) p.AllowAnyOrigin(); else p.WithOrigins(origins);
    p.AllowAnyHeader().AllowAnyMethod();
}));

var app = builder.Build();
app.UseCors();

var holdSeconds = int.TryParse(Environment.GetEnvironmentVariable("HOLD_DURATION_SECONDS"), out var hs) && hs > 0 ? hs : 600;
var studentIdRx = new Regex(@"^\d{17}$");

await InitDb(app);

IResult Err(int code, string message) => Results.Json(new { error = message }, statusCode: code);
string NewId(string prefix) => prefix + Guid.NewGuid().ToString("N")[..12];
string? StudentHeader(HttpRequest r) => r.Headers["X-Student-Id"].FirstOrDefault()?.Trim();
bool ValidStudent(string? s) => s is not null && studentIdRx.IsMatch(s);
string Effective(Hold h, DateTime now) => h.Status == "HELD" && h.ExpiresAt <= now ? "EXPIRED" : h.Status;
string Utc(DateTime d) => DateTime.SpecifyKind(d, DateTimeKind.Utc).ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
object HoldView(Hold h, DateTime now) => new { holdId = h.Id, classId = h.ClassId, studentId = h.StudentId, status = Effective(h, now), expiresAt = Utc(h.ExpiresAt) };

object ClassView(ClassEntity c, int held, int confirmed) => new
{
    id = c.Id, name = c.Name, totalSeats = c.TotalSeats,
    heldSeats = held, confirmedSeats = confirmed,
    availableSeats = Math.Max(0, c.TotalSeats - held - confirmed)
};

async Task<(int held, int confirmed)> Counts(AppDb db, string classId, DateTime now)
{
    var rows = await db.Holds.Where(h => h.ClassId == classId && (h.Status == "CONFIRMED" || (h.Status == "HELD" && h.ExpiresAt > now)))
        .GroupBy(h => h.Status).Select(g => new { g.Key, N = g.Count() }).ToListAsync();
    return (rows.FirstOrDefault(r => r.Key == "HELD")?.N ?? 0, rows.FirstOrDefault(r => r.Key == "CONFIRMED")?.N ?? 0);
}

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

// 1. Create class
app.MapPost("/classes", async (CreateClass? req, AppDb db) =>
{
    if (req is null || string.IsNullOrWhiteSpace(req.Name)) return Err(400, "Class name is required.");
    if (req.Name.Trim().Length > 200) return Err(400, "Class name is too long (max 200 characters).");
    if (req.TotalSeats is null || req.TotalSeats < 1 || req.TotalSeats > 1_000_000) return Err(400, "Total seats must be a whole number of at least 1.");
    var c = new ClassEntity { Id = NewId("c_"), Name = req.Name.Trim(), TotalSeats = req.TotalSeats.Value };
    db.Classes.Add(c);
    await db.SaveChangesAsync();
    return Results.Json(new { id = c.Id, name = c.Name, totalSeats = c.TotalSeats }, statusCode: 201);
});

// 2. List classes
app.MapGet("/classes", async (AppDb db) =>
{
    var now = DateTime.UtcNow;
    var classes = await db.Classes.OrderBy(c => c.Name).ThenBy(c => c.Id).ToListAsync();
    var counts = await db.Holds.Where(h => h.Status == "CONFIRMED" || (h.Status == "HELD" && h.ExpiresAt > now))
        .GroupBy(h => new { h.ClassId, h.Status }).Select(g => new { g.Key.ClassId, g.Key.Status, N = g.Count() }).ToListAsync();
    return Results.Ok(classes.Select(c => ClassView(c,
        counts.FirstOrDefault(x => x.ClassId == c.Id && x.Status == "HELD")?.N ?? 0,
        counts.FirstOrDefault(x => x.ClassId == c.Id && x.Status == "CONFIRMED")?.N ?? 0)));
});

// 3. One class
app.MapGet("/classes/{classId}", async (string classId, AppDb db) =>
{
    var c = await db.Classes.FindAsync(classId);
    if (c is null) return Err(404, "Class not found.");
    var (held, confirmed) = await Counts(db, classId, DateTime.UtcNow);
    return Results.Ok(ClassView(c, held, confirmed));
});

// 4. Apply (seat hold)
app.MapPost("/classes/{classId}/holds", async (string classId, HttpRequest req, AppDb db) =>
{
    var student = StudentHeader(req);
    if (!ValidStudent(student)) return Err(400, "X-Student-Id must be a 17-digit birth registration number.");
    if (!await db.Classes.AnyAsync(c => c.Id == classId)) return Err(404, "Class not found.");

    await using var tx = await db.Database.BeginTransactionAsync();
    // Row lock on the class serializes seat decisions per class across ALL backend processes sharing the DB.
    await db.Database.ExecuteSqlInterpolatedAsync($"SELECT 1 FROM classes WHERE \"Id\" = {classId} FOR UPDATE");
    var now = DateTime.UtcNow;
    var cls = await db.Classes.AsNoTracking().FirstAsync(c => c.Id == classId);
    // Release overdue holds of this class first so they neither count nor block the unique index.
    await db.Holds.Where(h => h.ClassId == classId && h.Status == "HELD" && h.ExpiresAt <= now)
        .ExecuteUpdateAsync(s => s.SetProperty(h => h.Status, "EXPIRED"));

    if (await db.Holds.AnyAsync(h => h.ClassId == classId && h.StudentId == student && (h.Status == "HELD" || h.Status == "CONFIRMED")))
        return Err(409, "You already have an active application or confirmed admission for this class.");

    var (held, confirmed) = await Counts(db, classId, now);
    if (held + confirmed >= cls.TotalSeats) return Err(409, "No seats are available in this class.");

    var hold = new Hold { Id = NewId("h_"), ClassId = classId, StudentId = student!, Status = "HELD", CreatedAt = now, ExpiresAt = now.AddSeconds(holdSeconds) };
    db.Holds.Add(hold);
    try { await db.SaveChangesAsync(); }
    catch (DbUpdateException) { return Err(409, "You already have an active application or confirmed admission for this class."); }
    await tx.CommitAsync();
    return Results.Json(HoldView(hold, now), statusCode: 201);
});

// 5. Hold status
app.MapGet("/holds/{holdId}", async (string holdId, AppDb db) =>
{
    var h = await db.Holds.AsNoTracking().FirstOrDefaultAsync(x => x.Id == holdId);
    if (h is null) return Err(404, "Application not found.");
    return Results.Ok(HoldView(h, DateTime.UtcNow));
});

// 6. Confirm (pay admission fee)
app.MapPost("/holds/{holdId}/confirm", async (string holdId, HttpRequest req, AppDb db) =>
{
    var student = StudentHeader(req);
    if (!ValidStudent(student)) return Err(400, "X-Student-Id must be a 17-digit birth registration number.");
    await using var tx = await db.Database.BeginTransactionAsync();
    var rows = await db.Holds.FromSqlInterpolated($"SELECT * FROM holds WHERE \"Id\" = {holdId} FOR UPDATE").ToListAsync();
    var h = rows.FirstOrDefault();
    if (h is null || h.StudentId != student) return Err(404, "Application not found.");
    var now = DateTime.UtcNow;
    if (h.Status == "CONFIRMED") return Results.Ok(new { holdId = h.Id, status = "CONFIRMED" }); // idempotent
    if (h.Status == "HELD" && h.ExpiresAt <= now)
    {
        h.Status = "EXPIRED";
        await db.SaveChangesAsync();
        await tx.CommitAsync();
        return Err(409, "This application has expired. Please apply again.");
    }
    if (h.Status != "HELD") return Err(409, $"This application is {h.Status.ToLowerInvariant()} and cannot be confirmed.");
    h.Status = "CONFIRMED";
    await db.SaveChangesAsync();
    await tx.CommitAsync();
    return Results.Ok(new { holdId = h.Id, status = "CONFIRMED" });
});

// 7. Cancel
app.MapDelete("/holds/{holdId}", async (string holdId, HttpRequest req, AppDb db) =>
{
    var student = StudentHeader(req);
    if (!ValidStudent(student)) return Err(400, "X-Student-Id must be a 17-digit birth registration number.");
    await using var tx = await db.Database.BeginTransactionAsync();
    var rows = await db.Holds.FromSqlInterpolated($"SELECT * FROM holds WHERE \"Id\" = {holdId} FOR UPDATE").ToListAsync();
    var h = rows.FirstOrDefault();
    if (h is null || h.StudentId != student) return Err(404, "Application not found.");
    if (h.Status == "CONFIRMED") return Err(409, "A confirmed admission cannot be cancelled here.");
    if (h.Status == "HELD")
    {
        h.Status = h.ExpiresAt <= DateTime.UtcNow ? "EXPIRED" : "CANCELLED";
        await db.SaveChangesAsync();
    }
    await tx.CommitAsync();
    return Results.NoContent(); // already EXPIRED/CANCELLED: idempotent 204
});

// 8. My applications
app.MapGet("/me/holds", async (HttpRequest req, AppDb db) =>
{
    var student = StudentHeader(req);
    if (!ValidStudent(student)) return Err(400, "X-Student-Id must be a 17-digit birth registration number.");
    var now = DateTime.UtcNow;
    var list = await (from h in db.Holds.AsNoTracking()
                      join c in db.Classes on h.ClassId equals c.Id
                      where h.StudentId == student
                      orderby h.CreatedAt descending
                      select new { h, c.Name }).ToListAsync();
    return Results.Ok(list.Select(x => new
    {
        holdId = x.h.Id, classId = x.h.ClassId, className = x.Name,
        status = Effective(x.h, now), expiresAt = Utc(x.h.ExpiresAt)
    }));
});

app.Run();

static string ConnectionString(IConfiguration cfg)
{
    var raw = Environment.GetEnvironmentVariable("DATABASE_URL") ?? cfg.GetConnectionString("Default")
        ?? "Host=localhost;Port=5432;Database=school_admission;Username=school;Password=school_pw";
    NpgsqlConnectionStringBuilder csb;
    if (raw.StartsWith("postgres://") || raw.StartsWith("postgresql://"))
    {
        // Neon/Render style URI -> Npgsql connection string
        var u = new Uri(raw);
        var ui = u.UserInfo.Split(':', 2);
        csb = new NpgsqlConnectionStringBuilder
        {
            Host = u.Host, Port = u.Port > 0 ? u.Port : 5432, Database = u.AbsolutePath.TrimStart('/'),
            Username = Uri.UnescapeDataString(ui[0]), Password = ui.Length > 1 ? Uri.UnescapeDataString(ui[1]) : "",
            SslMode = SslMode.Require
        };
    }
    else csb = new NpgsqlConnectionStringBuilder(raw);
    // A small pool makes a burst of requests queue for a connection instead of exhausting Postgres' max_connections
    // (each request holds its connection while it waits for the class row lock). Override via the connection string.
    if (!raw.Contains("Maximum Pool Size", StringComparison.OrdinalIgnoreCase) && !raw.Contains("MaxPoolSize", StringComparison.OrdinalIgnoreCase))
        csb.MaxPoolSize = 20;
    if (!raw.Contains("Timeout", StringComparison.OrdinalIgnoreCase)) csb.Timeout = 60;
    return csb.ConnectionString;
}

static async Task InitDb(WebApplication app)
{
    // Retry: Postgres (or a cold Neon instance) may not be ready yet, and two processes may race to create the schema.
    for (var attempt = 1; ; attempt++)
    {
        try
        {
            using var scope = app.Services.CreateScope();
            await scope.ServiceProvider.GetRequiredService<AppDb>().Database.EnsureCreatedAsync();
            return;
        }
        catch (Exception ex) when (attempt < 40)
        {
            app.Logger.LogWarning("DB not ready (attempt {n}): {m}", attempt, ex.Message);
            await Task.Delay(2000);
        }
    }
}

public record CreateClass(string? Name, int? TotalSeats);
public partial class Program { }
