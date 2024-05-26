using src.Observability;
using Microsoft.AspNetCore.Mvc;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration
    .AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile($"appsettings.{builder.Environment.EnvironmentName}.json", optional: true)
    .AddEnvironmentVariables();

builder.Services.AddObservability(builder.Configuration.GetSection("Observability").Get<ObservabilityOptions>() ?? new ObservabilityOptions());
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

if (!app.Environment.IsProduction())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/internal/openapi.json", "openapi");
    });
}

// Map openapi.json for swagger
app.MapGet("/internal/openapi.json", async (context) =>
{

    await context.Response.WriteAsync(await File.ReadAllTextAsync("./openapi.json"));
});

app.MapGet("/", ([FromServices] Instrumentation metrics, ILogger<Program> logger) => 
{
    // src of how to use the metrics
    metrics.RequestCount.Add(1);
    metrics.RequestDuration.Record(100, tag: new ("route", "/"));
    logger.LogWarning("Hello, from ADOT logger!");
    return Results.Ok("Hello, World!");
});

app.Run();
