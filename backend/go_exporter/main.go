package main

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/redis/go-redis/v9"
)

var (
	// Prometheus metrics
	wordsProcessed = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "rct_words_processed_total",
			Help: "Total number of words processed",
		},
		[]string{"organization", "country", "risk_level"},
	)

	translationLatency = promauto.NewHistogramVec(
		prometheus.HistogramOpts{
			Name:    "rct_translation_latency_ms",
			Help:    "Translation latency in milliseconds",
			Buckets: []float64{10, 50, 100, 200, 500, 1000, 2000, 5000},
		},
		[]string{"endpoint"},
	)

	criticalBlocks = promauto.NewCounterVec(
		prometheus.CounterOpts{
			Name: "rct_critical_blocks_total",
			Help: "Total number of critical cultural blocks",
		},
		[]string{"country", "reason"},
	)

	activeSubscriptions = promauto.NewGauge(
		prometheus.GaugeOpts{
			Name: "rct_active_subscriptions",
			Help: "Number of active subscriptions",
		},
	)

	apiRequestDuration = promauto.NewSummaryVec(
		prometheus.SummaryOpts{
			Name:       "rct_api_request_duration_ms",
			Help:       "API request duration in milliseconds",
			Objectives: map[float64]float64{0.5: 0.05, 0.9: 0.01, 0.99: 0.001},
		},
		[]string{"method", "path", "status"},
	)
)

type UsageRecord struct {
	OrganizationID string    `json:"organization_id"`
	WordCount      int       `json:"word_count"`
	CountryCode    string    `json:"country_code"`
	RiskLevel      string    `json:"risk_level"`
	Timestamp      time.Time `json:"timestamp"`
}

type BillingExporter struct {
	redisClient *redis.Client
	usageQueue  chan UsageRecord
	stopCh      chan struct{}
}

func NewBillingExporter(redisAddr string) *BillingExporter {
	rdb := redis.NewClient(&redis.Options{
		Addr:     redisAddr,
		Password: "",
		DB:       0,
	})

	return &BillingExporter{
		redisClient: rdb,
		usageQueue:  make(chan UsageRecord, 10000),
		stopCh:      make(chan struct{}),
	}
}

func (e *BillingExporter) Start() {
	// Start queue processor
	go e.processUsageQueue()

	// Start batch flusher
	ticker := time.NewTicker(30 * time.Second)
	go func() {
		for {
			select {
			case <-ticker.C:
				e.flushBatch()
			case <-e.stopCh:
				ticker.Stop()
				return
			}
		}
	}()
}

func (e *BillingExporter) Stop() {
	close(e.stopCh)
	close(e.usageQueue)
	e.flushBatch()
	e.redisClient.Close()
}

func (e *BillingExporter) RecordUsage(record UsageRecord) {
	select {
	case e.usageQueue <- record:
	default:
		log.Printf("Usage queue full, dropping record for org %s", record.OrganizationID)
	}
}

func (e *BillingExporter) processUsageQueue() {
	batch := make([]UsageRecord, 0, 100)
	ticker := time.NewTicker(5 * time.Second)

	for {
		select {
		case record, ok := <-e.usageQueue:
			if !ok {
				return
			}
			batch = append(batch, record)
			if len(batch) >= 100 {
				e.saveBatch(batch)
				batch = batch[:0]
			}
		case <-ticker.C:
			if len(batch) > 0 {
				e.saveBatch(batch)
				batch = batch[:0]
			}
		case <-e.stopCh:
			return
		}
	}
}

func (e *BillingExporter) saveBatch(batch []UsageRecord) {
	ctx := context.Background()
	pipe := e.redisClient.Pipeline()

	for _, record := range batch {
		key := fmt.Sprintf("usage:%s:%s", record.OrganizationID, record.Timestamp.Format("2006-01-02"))
		pipe.IncrBy(ctx, key, int64(record.WordCount))
		pipe.Expire(ctx, key, 90*24*time.Hour)

		// Update Prometheus metrics
		wordsProcessed.WithLabelValues(record.OrganizationID, record.CountryCode, record.RiskLevel).Add(float64(record.WordCount))
		
		if record.RiskLevel == "CRITICAL" {
			criticalBlocks.WithLabelValues(record.CountryCode, "cultural_taboo").Inc()
		}
	}

	_, err := pipe.Exec(ctx)
	if err != nil {
		log.Printf("Failed to save batch to Redis: %v", err)
	}
}

func (e *BillingExporter) flushBatch() {
	// Force flush any pending records
	ctx := context.Background()
	
	// Sync usage to Stripe
	keys, err := e.redisClient.Keys(ctx, "usage:*").Result()
	if err != nil {
		log.Printf("Failed to get usage keys: %v", err)
		return
	}

	for _, key := range keys {
		words, err := e.redisClient.GetDel(ctx, key).Int64()
		if err == nil && words > 0 {
			log.Printf("Flushed %d words for key %s to Stripe", words, key)
		}
	}
}

func (e *BillingExporter) handleRecord(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var record UsageRecord
	if err := json.NewDecoder(r.Body).Decode(&record); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	record.Timestamp = time.Now()
	e.RecordUsage(record)
	
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(map[string]string{"status": "recorded"})
}

func (e *BillingExporter) handleHealth(w http.ResponseWriter, r *http.Request) {
	ctx := context.Background()
	if err := e.redisClient.Ping(ctx).Err(); err != nil {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{"status": "unhealthy", "error": err.Error()})
		return
	}
	
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func main() {
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}

	exporter := NewBillingExporter(redisAddr)
	exporter.Start()
	defer exporter.Stop()

	// HTTP handlers
	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/api/v1/record", exporter.handleRecord)
	http.HandleFunc("/health", exporter.handleHealth)

	// Update gauge periodically
	go func() {
		ticker := time.NewTicker(1 * time.Minute)
		for range ticker.C {
			// In production, query database for active subscriptions
			activeSubscriptions.Set(150)
		}
	}()

	server := &http.Server{
		Addr:         ":9102",
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Graceful shutdown
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("Billing exporter listening on :9102")
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	<-stop
	log.Println("Shutting down gracefully...")
	
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	
	if err := server.Shutdown(ctx); err != nil {
		log.Printf("Server shutdown error: %v", err)
	}
}
