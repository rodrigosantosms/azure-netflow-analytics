using Azure.Identity;
using Kusto.Data.Net.Client;
using Kusto.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;

var builder = WebApplication.CreateBuilder(args);

// Config
var adxUri = builder.Configuration["ADX_URI"] ?? "";
var adxDb = builder.Configuration["ADX_DB"] ?? "";
var allowedOrigins = builder.Configuration["CORS_ORIGINS"] ?? "*";
var tenantId = builder.Configuration["ENTRA_TENANT_ID"] ?? "";

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(options => {
        builder.Configuration.Bind("AzureAd", options);
        options.TokenValidationParameters.ValidAudience = builder.Configuration["API_ENTRA_CLIENT_ID"];
        options.TokenValidationParameters.ValidIssuer = $"https://sts.windows.net/{tenantId}/";
    }, options => {
        builder.Configuration.Bind("AzureAd", options);
    });

builder.Services.AddAuthorization();
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p
    .WithOrigins(allowedOrigins.Split(',', StringSplitOptions.RemoveEmptyEntries))
    .AllowAnyHeader()
    .AllowAnyMethod()
));

var app = builder.Build();

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

// Kusto client factory
ICslQueryProvider CreateQueryProvider() {
    var kcsb = new KustoConnectionStringBuilder(adxUri)
        .WithAadAzureTokenCredentialsAuthentication(new DefaultAzureCredential());
    return KustoClientFactory.CreateCslQueryProvider(kcsb);
}

// Health
app.MapGet("/api/health", () => Results.Ok(new { ok = true, time = DateTime.UtcNow }));

// Top Talkers (bar)
app.MapGet("/api/top-talkers", async (HttpContext ctx, int top = 50, string? scope = null, string window = "PT1H") => {
    using var q = CreateQueryProvider();
    var query = $@"
let start = now() - {window};
mv_topTalkers_5m
| where FiveMinBin >= start
{(string.IsNullOrEmpty(scope) ? "" : $"| where {scope}")}
| summarize Bytes=sum(Bytes), Flows=sum(Flows) by SrcVm, DstVm, DstPort
| top {top} by Bytes desc
";
    var reader = await q.ExecuteQueryV2Async(adxDb, query);
    var rows = new List<Dictionary<string, object>>();
    while (reader.Read())
    {
        var dict = Enumerable.Range(0, reader.FieldCount).ToDictionary(reader.GetName, reader.GetValue);
        rows.Add(dict);
    }
    return Results.Ok(rows);
});

// Heatmap (source x destination)
app.MapGet("/api/heatmap", async (HttpContext ctx, int topSources = 20, int topDests = 20, string window = "PT1H") => {
    using var q = CreateQueryProvider();
    var query = $@"
let start = now() - {window};
let sums = mv_heatmap_5m
| where FiveMinBin >= start
| summarize Bytes=sum(Bytes) by SrcVm, DstVm;
let topSrc = sums | summarize Bytes=sum(Bytes) by SrcVm | top {topSources} by Bytes desc | project SrcVm;
let topDst = sums | summarize Bytes=sum(Bytes) by DstVm | top {topDests} by Bytes desc | project DstVm;
sums
| where SrcVm in (topSrc) and DstVm in (topDst)
| project SrcVm, DstVm, Bytes
";
    var reader = await q.ExecuteQueryV2Async(adxDb, query);
    var rows = new List<Dictionary<string, object>>();
    while (reader.Read())
    {
        var dict = Enumerable.Range(0, reader.FieldCount).ToDictionary(reader.GetName, reader.GetValue);
        rows.Add(dict);
    }
    return Results.Ok(rows);
});

app.Run();
