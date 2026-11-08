using Microsoft.EntityFrameworkCore;

namespace SchoolAdmission.Api;

public class ClassEntity
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public int TotalSeats { get; set; }
}

public class Hold
{
    public string Id { get; set; } = "";
    public string ClassId { get; set; } = "";
    public string StudentId { get; set; } = "";
    /// <summary>Stored status: HELD, CONFIRMED, EXPIRED or CANCELLED. A HELD row past ExpiresAt is treated as EXPIRED everywhere.</summary>
    public string Status { get; set; } = "HELD";
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; }
}

public class AppDb(DbContextOptions<AppDb> options) : DbContext(options)
{
    public DbSet<ClassEntity> Classes => Set<ClassEntity>();
    public DbSet<Hold> Holds => Set<Hold>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        b.Entity<ClassEntity>(e =>
        {
            e.ToTable("classes");
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).HasMaxLength(200);
        });
        b.Entity<Hold>(e =>
        {
            e.ToTable("holds");
            e.HasKey(x => x.Id);
            e.Property(x => x.StudentId).HasMaxLength(17);
            e.Property(x => x.Status).HasMaxLength(16);
            e.HasIndex(x => new { x.ClassId, x.StudentId }).IsUnique()
                .HasFilter("\"Status\" IN ('HELD','CONFIRMED')");
            e.HasIndex(x => x.StudentId);
            e.HasIndex(x => new { x.ClassId, x.Status });
        });
    }
}
