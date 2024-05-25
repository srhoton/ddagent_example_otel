using System.Diagnostics.Metrics;
using OpenTelemetry;
using OpenTelemetry.Contrib.Extensions.AWSXRay.Trace;
using OpenTelemetry.Instrumentation.AspNetCore;
using OpenTelemetry.Logs;
using OpenTelemetry.Resources;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;
using Microsoft.AspNetCore.Mvc;

namespace src.Observability;

/// <summary>
/// Represents the options for observability.
/// </summary>
public record ObservabilityOptions
{
    /// <summary>
    /// Gets or sets the service name.
    /// </summary>
    public string ServiceName { get; init; } = "Value not set";

    /// <summary>
    /// Gets or sets the tracing exporter to use.
    /// </summary>
    /// <remarks>
    /// Valid values: "console", "otlp".
    /// </remarks>
    public string UseTracingExporter { get; init; } = "console";

    /// <summary>
    /// Gets or sets the metrics exporter to use.
    /// </summary>
    /// <remarks>
    /// Valid values: "console", "otlp".
    /// </remarks>
    public string UseMetricsExporter { get; init; } = "console";

    /// <summary>
    /// Gets or sets the logging exporter to use.
    /// </summary>
    /// <remarks>
    /// Valid values: "console", "otlp".
    /// </remarks>
    public string UseLoggingExporter { get; init; } = "console";

    /// <summary>
    /// Gets or sets the histogram aggregation method.
    /// </summary>
    /// <remarks>
    /// Valid values: "explicit", "exponential".
    /// </remarks>
    public string HistogramAggregation { get; init; } = "explicit";

    /// <summary>
    /// Represents the options for OpenTelemetry Protocol (OTLP) exporter.
    /// </summary>
    public record OtlpOptions
    {
        /// <summary>
        /// Gets or sets the endpoint for the OTLP exporter.
        /// </summary>
        public string Endpoint { get; init; } = "http://localhost:4317";
    }

    /// <summary>
    /// Gets or sets the OTLP options.
    /// </summary>
    public OtlpOptions Otlp { get; init; } = new OtlpOptions();
}

public static class ObservabilityExtensions
{
    public static void AddObservability(this IServiceCollection services, ObservabilityOptions options)
    {
        // Build a resource configuration action to set service information.
        Action<ResourceBuilder> configureResource = r => r.AddService(
            serviceName: options!.ServiceName,
            serviceVersion: typeof(Program).Assembly.GetName().Version?.ToString() ?? "unknown", // This always defaults to 1.0.0.0 unless you specify it.
            serviceInstanceId: Environment.MachineName);

        // Inject instrumentation into the DI container.
        services.AddSingleton<Instrumentation>();

        // Configure OpenTelemetry tracing & metrics with auto-start using the
        // AddOpenTelemetry extension from OpenTelemetry.Extensions.Hosting.
        services.AddOpenTelemetry()
            .ConfigureResource(configureResource)
            .WithTracing(builder =>
            {
                builder
                    .AddSource(Instrumentation.ActivitySourceName)
                    .AddXRayTraceId()
                    .AddAWSInstrumentation()
                    .SetSampler(new AlwaysOnSampler())
                    .AddGrpcClientInstrumentation()
                    .AddHttpClientInstrumentation()
                    .AddAspNetCoreInstrumentation();

                switch (options!.UseTracingExporter)
                {
                    case "otlp":
                        builder.AddOtlpExporter(ops =>
                        {
                            ops.Endpoint = new Uri(options.Otlp.Endpoint);
                        });
                        Sdk.SetDefaultTextMapPropagator(new AWSXRayPropagator());
                        break;

                    default:
                        builder.AddConsoleExporter();
                        break;
                }
            })
            .WithMetrics(builder =>
            {
                builder
                    .AddMeter(Instrumentation.MeterName, "Microsoft.AspNetCore.Hosting", "Microsoft.AspNetCore.Server.Kestrel")
                    .AddHttpClientInstrumentation();

                switch (options!.HistogramAggregation)
                {
                    case "exponential":
                        Console.WriteLine("Using ExponentialBucketHistogram for Metrics");
                        builder.AddView(instrument =>
                        {
                            return instrument.GetType().GetGenericTypeDefinition() == typeof(Histogram<>)
                                ? new Base2ExponentialBucketHistogramConfiguration()
                                : null;
                        });
                        break;
                    default:
                        Console.WriteLine("Using ExplicitBoundsHistogram for Metrics");
                        // Explicit bounds histogram is the default.
                        // No additional configuration necessary.
                        break;
                }

                switch (options.UseMetricsExporter)
                {
                    case "otlp":
                        Console.WriteLine("Using OtlpExporter for Metrics");
                        builder.AddOtlpExporter(otlpOptions =>
                        {
                            // Use IConfiguration directly for Otlp exporter endpoint option.
                            otlpOptions.Endpoint = new Uri(options.Otlp.Endpoint);
                        });
                        break;
                    default:
                        Console.WriteLine("Using ConsoleExporter for Metrics");
                        builder.AddConsoleExporter();
                        break;
                }
            });
    }

    public static void AddObservabilityLogging(this ILoggingBuilder logging, ObservabilityOptions options)
    {
        // Clear default logging providers used by WebApplication host.
        logging.ClearProviders();

        logging.AddOpenTelemetry(ops =>
        {
            // Build a resource configuration action to set service information.
            Action<ResourceBuilder> configureResource = r => r.AddService(
                serviceName: options.ServiceName,
                serviceVersion: typeof(Program).Assembly.GetName().Version?.ToString() ?? "unknown", // This always defaults to 1.0.0.0 unless you specify it.
                serviceInstanceId: Environment.MachineName);

            var resourceBuilder = ResourceBuilder.CreateDefault();
            configureResource(resourceBuilder);
            ops.SetResourceBuilder(resourceBuilder);

            switch (options.UseLoggingExporter)
            {
                case "otlp":
                    ops.AddOtlpExporter(otlpOptions =>
                    {
                        // Use IConfiguration directly for Otlp exporter endpoint option.
                        otlpOptions.Endpoint = new Uri(options.Otlp.Endpoint);
                    });
                    break;
                default:
                    ops.AddConsoleExporter();
                    break;
            }
        });
    }
}