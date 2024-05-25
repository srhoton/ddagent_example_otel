using System.Collections.Concurrent;
using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace src.Observability;
/// <summary>
/// Holds the instrumentation for the Kafka consumer. These are metrics
/// that are collected and reported to the open telemetry backend.
/// </summary>
public class Instrumentation : IDisposable
{
    /// <summary>
    /// The name of the activity source.
    /// </summary>
    internal const string ActivitySourceName = "src.Metrics";

    /// <summary>
    /// The name of the meter.
    /// </summary>
    internal const string MeterName = "src.Metrics";

    /// <summary>
    /// The meter that holds the metrics.
    /// </summary>
    private readonly Meter meter;

    /// <summary>
    /// Activity source for the instrumentation.
    /// </summary>
    public ActivitySource ActivitySource { get; }

    /// <summary>
    /// Basic counter metric for the number of requests made.
    /// </summary>
    public Counter<long> RequestCount { get; }

    /// <summary>
    /// Basic Histogram metric for the duration of requests made.
    /// </summary>
    public Histogram<long> RequestDuration { get; }

    public Instrumentation(IMeterFactory meterFactory)
    {
        string version = typeof(Instrumentation).Assembly.GetName().Version?.ToString() ?? "unknown";
        meter = meterFactory.Create(MeterName, version);
        ActivitySource = new ActivitySource(ActivitySourceName, version);

        RequestCount = meter.CreateCounter<long>("src.requests.count", description: "The number of requests made.", unit: "{requests}");
        RequestDuration = meter.CreateHistogram<long>("src.requests.duration", description: "The duration of requests made.", unit: "ms");
    }

    public void Dispose()
    {
        ActivitySource.Dispose();
        meter.Dispose();
    }
}