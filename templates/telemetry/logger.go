package telemetry

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"time"

	"go.opentelemetry.io/otel/trace"
)

// Severity levels matching OpenTelemetry SemConv
const (
	SeverityTrace = "TRACE"
	SeverityDebug = "DEBUG"
	SeverityInfo  = "INFO"
	SeverityWarn  = "WARN"
	SeverityError = "ERROR"
	SeverityFatal = "FATAL"
)

// MasterLogRecord represents the single source of truth for telemetry log records.
// All fields use omitempty to avoid polluting storage with empty or null fields.
type MasterLogRecord struct {
	Timestamp            string                `json:"timestamp"`
	ObservedTimestamp    string                `json:"observed_timestamp,omitempty"`
	SeverityText         string                `json:"severity_text"`
	SeverityNumber       int                   `json:"severity_number"`
	EventName            string                `json:"event_name,omitempty"`
	Body                 string                `json:"body"`
	TraceID              string                `json:"trace_id,omitempty"`
	SpanID               string                `json:"span_id,omitempty"`
	TraceFlags           string                `json:"trace_flags,omitempty"`
	Resource             ResourceAttributes    `json:"resource"`
	Attributes           LogAttributes         `json:"attributes"`
	InstrumentationScope *InstrumentationScope `json:"instrumentation_scope,omitempty"`
	SchemaURL            string                `json:"schema_url,omitempty"`
}

// ResourceAttributes describes the entity producing the telemetry.
type ResourceAttributes struct {
	ServiceName         string `json:"service.name"`
	ServiceNamespace    string `json:"service.namespace,omitempty"`
	ServiceVersion      string `json:"service.version,omitempty"`
	ServiceInstanceID   string `json:"service.instance.id,omitempty"`
	EnvironmentName     string `json:"deployment.environment.name"`
	CloudProvider       string `json:"cloud.provider,omitempty"`
	CloudRegion         string `json:"cloud.region,omitempty"`
	CloudAZ             string `json:"cloud.availability_zone,omitempty"`
	K8sClusterName      string `json:"k8s.cluster.name,omitempty"`
	K8sNamespaceName    string `json:"k8s.namespace.name,omitempty"`
	K8sDeploymentName   string `json:"k8s.deployment.name,omitempty"`
	K8sPodName          string `json:"k8s.pod.name,omitempty"`
	K8sPodUID           string `json:"k8s.pod.uid,omitempty"`
	K8sNodeName         string `json:"k8s.node.name,omitempty"`
	ContainerID         string `json:"container.id,omitempty"`
	ContainerImageName  string `json:"container.image.name,omitempty"`
	ContainerImageTag   string `json:"container.image.tag,omitempty"`
	ProcessRuntimeName  string `json:"process.runtime.name,omitempty"`
	ProcessRuntimeVer   string `json:"process.runtime.version,omitempty"`
	VCSHeadRevision     string `json:"vcs.ref.head.revision,omitempty"`
	AppBuildID          string `json:"app.build.id,omitempty"`
	TelemetrySDKName    string `json:"telemetry.sdk.name,omitempty"`
	TelemetrySDKLang    string `json:"telemetry.sdk.language,omitempty"`
	TelemetrySDKVersion string `json:"telemetry.sdk.version,omitempty"`
}

// LogAttributes holds all business, protocol, execution, and error attributes.
type LogAttributes struct {
	// Business & Request context
	AppRequestID      string  `json:"app.request_id,omitempty"`
	AppCorrelationID  string  `json:"app.correlation_id,omitempty"`
	AppCausationID    string  `json:"app.causation_id,omitempty"`
	AppBusinessRef    string  `json:"app.business_ref,omitempty"`
	AppTenantID       string  `json:"app.tenant_id,omitempty"`
	AppChannel        string  `json:"app.channel,omitempty"`
	AppUserIDHash     string  `json:"app.user.id_hash,omitempty"`
	AppIdempotencyKey string  `json:"app.idempotency_key,omitempty"`
	AppRetryAttempt   int     `json:"app.retry_attempt,omitempty"`
	AppDurationMs     float64 `json:"app.duration_ms,omitempty"`
	AppOutcome        string  `json:"app.outcome,omitempty"` // success, failure, pending
	AppFeatureFlags   string  `json:"app.feature_flags,omitempty"`
	AppTraceOrigin    string  `json:"app.trace_origin,omitempty"`

	// HTTP attributes
	HTTPRequestMethod     string `json:"http.request.method,omitempty"`
	HTTPRoute             string `json:"http.route,omitempty"`
	URLPath               string `json:"url.path,omitempty"`
	URLScheme             string `json:"url.scheme,omitempty"`
	HTTPResponseStatus    int    `json:"http.response.status_code,omitempty"`
	HTTPRequestSize       int64  `json:"http.request.body.size,omitempty"`
	HTTPResponseSize      int64  `json:"http.response.body.size,omitempty"`
	NetworkProtocolName   string `json:"network.protocol.name,omitempty"`
	NetworkProtocolVer    string `json:"network.protocol.version,omitempty"`
	ClientAddress         string `json:"client.address,omitempty"`
	UserAgentOriginal     string `json:"user_agent.original,omitempty"`
	ServerAddress         string `json:"server.address,omitempty"`
	ServerPort            int    `json:"server.port,omitempty"`

	// Database attributes
	DBSystemName          string  `json:"db.system.name,omitempty"`
	DBNamespace           string  `json:"db.namespace,omitempty"`
	DBOperationName       string  `json:"db.operation.name,omitempty"`
	DBCollectionName      string  `json:"db.collection.name,omitempty"`
	DBQueryText           string  `json:"db.query.text,omitempty"`
	DBReturnedRows        int     `json:"db.response.returned_rows,omitempty"`
	DBResponseStatusCode  string  `json:"db.response.status_code,omitempty"`
	AppDBPoolWaitMs       float64 `json:"app.db.pool_wait_ms,omitempty"`
	AppDBQueryMs          float64 `json:"app.db.query_ms,omitempty"`

	// Messaging attributes
	MessagingSystem       string `json:"messaging.system,omitempty"`
	MessagingOpType       string `json:"messaging.operation.type,omitempty"`
	MessagingOpName       string `json:"messaging.operation.name,omitempty"`
	MessagingDestName     string `json:"messaging.destination.name,omitempty"`
	MessagingDestPartID   string `json:"messaging.destination.partition.id,omitempty"`
	MessagingKafkaOffset  int64  `json:"messaging.kafka.offset,omitempty"`
	MessagingKafkaKey     string `json:"messaging.kafka.message.key,omitempty"`
	MessagingConsumerGrp  string `json:"messaging.consumer.group.name,omitempty"`
	MessagingMessageID    string `json:"messaging.message.id,omitempty"`
	MessagingMsgBodySize  int64  `json:"messaging.message.body.size,omitempty"`
	AppConsumerLagMs      int64  `json:"app.consumer.lag_ms,omitempty"`
	AppDeliveryAttempt    int    `json:"app.delivery_attempt,omitempty"`
	AppDLQ                bool   `json:"app.dlq,omitempty"`

	// Saga & Workflow attributes
	AppSagaID           string `json:"app.saga.id,omitempty"`
	AppSagaType         string `json:"app.saga.type,omitempty"`
	AppSagaStep         string `json:"app.saga.step,omitempty"`
	AppSagaStepIndex    int    `json:"app.saga.step_index,omitempty"`
	AppSagaStepStatus   string `json:"app.saga.step_status,omitempty"`
	AppSagaCompensating bool   `json:"app.saga.compensating,omitempty"`

	// Batch / Job attributes
	AppJobName          string `json:"app.job.name,omitempty"`
	AppJobID            string `json:"app.job.id,omitempty"`
	AppJobRunID         string `json:"app.job.run_id,omitempty"`
	AppJobTrigger       string `json:"app.job.trigger,omitempty"`
	AppJobRecProcessed  int64  `json:"app.job.records_processed,omitempty"`
	AppJobRecFailed     int64  `json:"app.job.records_failed,omitempty"`

	// Error attributes
	ErrorType          string `json:"error.type,omitempty"`
	ExceptionType      string `json:"exception.type,omitempty"`
	ExceptionMessage   string `json:"exception.message,omitempty"`
	ExceptionStacktrace string `json:"exception.stacktrace,omitempty"`
	AppErrorCode       string `json:"app.error_code,omitempty"`
	AppErrorCategory   string `json:"app.error.category,omitempty"`
	AppRetryable       bool   `json:"app.retryable,omitempty"`
}

type InstrumentationScope struct {
	Name    string `json:"name"`
	Version string `json:"version,omitempty"`
}

// Logger wraps standard output writer and default base resource.
type Logger struct {
	baseResource ResourceAttributes
	output       io.Writer
}

// NewLogger initializes a new Logger pre-populated with standard resource attributes.
func NewLogger(serviceName, env string) *Logger {
	return &Logger{
		baseResource: ResourceAttributes{
			ServiceName:        serviceName,
			EnvironmentName:    env,
			ServiceNamespace:   os.Getenv("SERVICE_NAMESPACE"),
			ServiceVersion:     os.Getenv("SERVICE_VERSION"),
			K8sPodName:         os.Getenv("POD_NAME"),
			K8sNamespaceName:   os.Getenv("POD_NAMESPACE"),
			K8sNodeName:        os.Getenv("NODE_NAME"),
			ProcessRuntimeName: "go",
		},
		output: os.Stdout,
	}
}

// LogEntry builder for chaining attributes.
type LogEntry struct {
	logger *Logger
	ctx    context.Context
	record MasterLogRecord
}

// WithContext starts a new log entry builder extracting active trace span.
func (l *Logger) WithContext(ctx context.Context) *LogEntry {
	entry := &LogEntry{
		logger: l,
		ctx:    ctx,
		record: MasterLogRecord{
			Timestamp: time.Now().UTC().Format(time.RFC3339Nano),
			Resource:  l.baseResource,
			SchemaURL: "https://opentelemetry.io/schemas/1.x.0",
		},
	}

	// Extract active OTel span if present
	if span := trace.SpanFromContext(ctx); span.SpanContext().IsValid() {
		sc := span.SpanContext()
		entry.record.TraceID = sc.TraceID().String()
		entry.record.SpanID = sc.SpanID().String()
		entry.record.TraceFlags = sc.TraceFlags().String()
	}

	return entry
}

// WithBusiness sets business correlation identifiers.
func (e *LogEntry) WithBusiness(reqID, corrID, bizRef string) *LogEntry {
	e.record.Attributes.AppRequestID = reqID
	e.record.Attributes.AppCorrelationID = corrID
	e.record.Attributes.AppBusinessRef = bizRef
	return e
}

// WithHTTP sets HTTP server or client attributes.
func (e *LogEntry) WithHTTP(method, route string, statusCode int, durationMs float64) *LogEntry {
	e.record.Attributes.HTTPRequestMethod = method
	e.record.Attributes.HTTPRoute = route
	e.record.Attributes.HTTPResponseStatus = statusCode
	e.record.Attributes.AppDurationMs = durationMs
	return e
}

// WithDB sets database attributes.
func (e *LogEntry) WithDB(system, op, table string, queryMs float64) *LogEntry {
	e.record.Attributes.DBSystemName = system
	e.record.Attributes.DBOperationName = op
	e.record.Attributes.DBCollectionName = table
	e.record.Attributes.AppDBQueryMs = queryMs
	return e
}

// WithError sets error and exception fields.
func (e *LogEntry) WithError(err error, errCode string, retryable bool) *LogEntry {
	if err != nil {
		e.record.Attributes.ErrorType = fmt.Sprintf("%T", err)
		e.record.Attributes.ExceptionMessage = err.Error()
		e.record.Attributes.AppErrorCode = errCode
		e.record.Attributes.AppRetryable = retryable
		e.record.Attributes.AppOutcome = "failure"
	}
	return e
}

// Info logs an informational message.
func (e *LogEntry) Info(msg string) {
	e.record.SeverityText = SeverityInfo
	e.record.SeverityNumber = 9
	e.record.Body = msg
	e.emit()
}

// Error logs an error message.
func (e *LogEntry) Error(msg string) {
	e.record.SeverityText = SeverityError
	e.record.SeverityNumber = 17
	e.record.Body = msg
	e.emit()
}

func (e *LogEntry) emit() {
	data, err := json.Marshal(e.record)
	if err == nil {
		fmt.Fprintln(e.logger.output, string(data))
	}
}
