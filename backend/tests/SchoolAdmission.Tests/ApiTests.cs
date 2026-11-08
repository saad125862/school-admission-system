using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Xunit;

namespace SchoolAdmission.Tests;

/// <summary>Spins the real API in-process against a real Postgres (the compose "postgres" service on localhost:5432,
/// or TEST_DATABASE_URL). Hold duration is 3s so expiry can be tested quickly.</summary>
public class ApiFixture : WebApplicationFactory<Program>
{
    public ApiFixture()
    {
        Environment.SetEnvironmentVariable("DATABASE_URL", Environment.GetEnvironmentVariable("TEST_DATABASE_URL")
            ?? "Host=localhost;Port=5432;Database=school_admission_test;Username=school;Password=school_pw");
        Environment.SetEnvironmentVariable("HOLD_DURATION_SECONDS", "3");
    }
}

public class ApiTests(ApiFixture factory) : IClassFixture<ApiFixture>
{
    private readonly HttpClient _http = factory.CreateClient();
    private static int _studentCounter = 0;

    private static string NewStudent() => "9" + Interlocked.Increment(ref _studentCounter).ToString("D6") + Random.Shared.NextInt64(0, 9_999_999_999).ToString("D10");

    private async Task<string> CreateClass(int seats)
    {
        var res = await _http.PostAsJsonAsync("/classes", new { name = "Test " + Guid.NewGuid().ToString("N")[..6], totalSeats = seats });
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        return (await res.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetString()!;
    }

    private Task<HttpResponseMessage> Send(HttpMethod m, string url, string? student)
    {
        var req = new HttpRequestMessage(m, url);
        if (student is not null) req.Headers.Add("X-Student-Id", student);
        return _http.SendAsync(req);
    }

    private async Task<JsonElement> GetClass(string id) =>
        await (await _http.GetAsync($"/classes/{id}")).Content.ReadFromJsonAsync<JsonElement>();

    [Fact]
    public async Task Concurrent_applications_never_exceed_total_seats()
    {
        const int seats = 10, applicants = 100;
        var cls = await CreateClass(seats);
        var results = await Task.WhenAll(Enumerable.Range(0, applicants)
            .Select(_ => Task.Run(() => Send(HttpMethod.Post, $"/classes/{cls}/holds", NewStudent()))));

        Assert.Equal(seats, results.Count(r => r.StatusCode == HttpStatusCode.Created));
        var others = results.Where(r => r.StatusCode != HttpStatusCode.Conflict && r.StatusCode != HttpStatusCode.Created).Select(r => (int)r.StatusCode + ":" + r.Content.ReadAsStringAsync().Result).ToList();
        Assert.True(others.Count == 0, "Unexpected responses: " + string.Join(" | ", others));
        Assert.Equal(applicants - seats, results.Count(r => r.StatusCode == HttpStatusCode.Conflict));
        var c = await GetClass(cls);
        Assert.Equal(seats, c.GetProperty("heldSeats").GetInt32());
        Assert.Equal(0, c.GetProperty("availableSeats").GetInt32());
    }

    [Fact]
    public async Task Confirm_is_idempotent_and_counts_the_seat_once()
    {
        var cls = await CreateClass(5);
        var student = NewStudent();
        var hold = await (await Send(HttpMethod.Post, $"/classes/{cls}/holds", student)).Content.ReadFromJsonAsync<JsonElement>();
        var holdId = hold.GetProperty("holdId").GetString();

        var confirms = await Task.WhenAll(Enumerable.Range(0, 5)
            .Select(_ => Task.Run(() => Send(HttpMethod.Post, $"/holds/{holdId}/confirm", student))));
        Assert.All(confirms, r => Assert.Equal(HttpStatusCode.OK, r.StatusCode));

        var c = await GetClass(cls);
        Assert.Equal(1, c.GetProperty("confirmedSeats").GetInt32());
        Assert.Equal(0, c.GetProperty("heldSeats").GetInt32());
        Assert.Equal(4, c.GetProperty("availableSeats").GetInt32());
    }

    [Fact]
    public async Task Expired_hold_frees_the_seat_without_any_api_call_and_cannot_be_confirmed()
    {
        var cls = await CreateClass(1);
        var student = NewStudent();
        var hold = await (await Send(HttpMethod.Post, $"/classes/{cls}/holds", student)).Content.ReadFromJsonAsync<JsonElement>();
        var holdId = hold.GetProperty("holdId").GetString();
        Assert.Equal(HttpStatusCode.Conflict, (await Send(HttpMethod.Post, $"/classes/{cls}/holds", NewStudent())).StatusCode);

        await Task.Delay(TimeSpan.FromSeconds(4.5)); // hold duration is 3s

        Assert.Equal(1, (await GetClass(cls)).GetProperty("availableSeats").GetInt32());
        var status = await (await _http.GetAsync($"/holds/{holdId}")).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("EXPIRED", status.GetProperty("status").GetString());
        Assert.Equal(HttpStatusCode.Conflict, (await Send(HttpMethod.Post, $"/holds/{holdId}/confirm", student)).StatusCode);
        Assert.Equal(HttpStatusCode.Created, (await Send(HttpMethod.Post, $"/classes/{cls}/holds", NewStudent())).StatusCode);
    }

    [Fact]
    public async Task Same_student_cannot_hold_twice_and_other_students_cannot_touch_the_hold()
    {
        var cls = await CreateClass(5);
        var student = NewStudent();
        var first = await Send(HttpMethod.Post, $"/classes/{cls}/holds", student);
        Assert.Equal(HttpStatusCode.Created, first.StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Send(HttpMethod.Post, $"/classes/{cls}/holds", student)).StatusCode);

        var holdId = (await first.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("holdId").GetString();
        var stranger = NewStudent();
        Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Post, $"/holds/{holdId}/confirm", stranger)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await Send(HttpMethod.Delete, $"/holds/{holdId}", stranger)).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Send(HttpMethod.Post, $"/classes/{cls}/holds", "123")).StatusCode);
        Assert.Equal(HttpStatusCode.BadRequest, (await Send(HttpMethod.Post, $"/classes/{cls}/holds", null)).StatusCode);
    }

    [Fact]
    public async Task Cancelling_frees_the_seat_and_my_holds_lists_the_application()
    {
        var cls = await CreateClass(1);
        var student = NewStudent();
        var hold = await (await Send(HttpMethod.Post, $"/classes/{cls}/holds", student)).Content.ReadFromJsonAsync<JsonElement>();
        var holdId = hold.GetProperty("holdId").GetString();

        var mine = await (await Send(HttpMethod.Get, "/me/holds", student)).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, mine.GetArrayLength());
        Assert.Equal("HELD", mine[0].GetProperty("status").GetString());
        Assert.True(mine[0].TryGetProperty("className", out _));

        Assert.Equal(HttpStatusCode.NoContent, (await Send(HttpMethod.Delete, $"/holds/{holdId}", student)).StatusCode);
        Assert.Equal(1, (await GetClass(cls)).GetProperty("availableSeats").GetInt32());
        mine = await (await Send(HttpMethod.Get, "/me/holds", student)).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("CANCELLED", mine[0].GetProperty("status").GetString());
        // re-applying after cancel is allowed
        Assert.Equal(HttpStatusCode.Created, (await Send(HttpMethod.Post, $"/classes/{cls}/holds", student)).StatusCode);
    }
}
