from locust import HttpUser, task, between, events
import random
import json
from datetime import datetime

class AdvancedRCTUser(HttpUser):
    wait_time = between(0.5, 3)
    
    def on_start(self):
        """Login and get API key"""
        self.api_key = "test_key_advanced"
        self.headers = {"X-API-Key": self.api_key, "Content-Type": "application/json"}
        
        # Test data sets
        self.simple_texts = [
            "Hello world",
            "Good morning",
            "Thank you for your help",
            "I would like to schedule a meeting",
            "Please send me the report"
        ]
        
        self.complex_texts = [
            "We need to finalize the merger agreement by Friday",
            "The quarterly earnings exceeded expectations by 15%",
            "Please review the attached legal documents",
            "The patient requires immediate medical attention",
            "The software architecture needs to be redesigned"
        ]
        
        self.slang_texts = [
            "Piga chini ofisi za zamani",
            "Kula pesa ni haramu",
            "Haram content warning",
            "牛逼 performance",
            "That's lit fr fr no cap"
        ]
        
        self.countries = ["KE", "TZ", "SA", "CN", "NG", "US", "GB", "FR", "DE", "JP"]
        self.industries = ["marketing", "legal", "medical", "technical", "diplomatic"]
    
    @task(5)
    def translate_simple(self):
        """Simple translation - high frequency"""
        text = random.choice(self.simple_texts)
        country = random.choice(self.countries)
        
        payload = {
            "source_text": text,
            "source_language": "en",
            "target_country": country,
            "target_language": "sw"
        }
        
        with self.client.post(
            "/api/v1/translate",
            json=payload,
            headers=self.headers,
            catch_response=True
        ) as response:
            if response.status_code == 200:
                data = response.json()
                if data.get("cultural_intelligence", {}).get("risk_matrix_rating") == "CRITICAL":
                    response.success()
                else:
                    response.success()
            elif response.status_code == 429:
                response.success()  # Rate limiting is expected
            else:
                response.failure(f"Unexpected status: {response.status_code}")
    
    @task(3)
    def translate_complex(self):
        """Complex translation - medium frequency"""
        text = random.choice(self.complex_texts)
        country = random.choice(self.countries)
        industry = random.choice(self.industries)
        
        payload = {
            "source_text": text,
            "source_language": "en",
            "target_country": country,
            "target_language": "sw",
            "industry_vertical": industry,
            "preserve_tone": True,
            "detect_slang": True
        }
        
        self.client.post("/api/v1/translate", json=payload, headers=self.headers)
    
    @task(2)
    def translate_slang(self):
        """Slang translation - tests cultural detection"""
        text = random.choice(self.slang_texts)
        
        payload = {
            "source_text": text,
            "source_language": "sw",
            "target_country": "KE",
            "target_language": "en"
        }
        
        self.client.post("/api/v1/translate", json=payload, headers=self.headers)
    
    @task(1)
    def batch_translate(self):
        """Batch translation - low frequency"""
        batch = []
        for i in range(5):
            batch.append({
                "source_text": f"Batch test message {i}",
                "source_language": "en",
                "target_country": random.choice(self.countries),
                "target_language": "sw"
            })
        
        payload = {"texts": batch}
        self.client.post("/api/v1/batch/translate", json=payload, headers=self.headers)
    
    @task(1)
    def get_analytics(self):
        """Analytics endpoint"""
        self.client.get("/api/v1/analytics/dashboard?days=7", headers=self.headers)
    
    @task(1)
    def get_billing(self):
        """Billing endpoint"""
        self.client.get("/api/v1/billing/plan", headers=self.headers)
    
    @task(1)
    def get_alerts(self):
        """Alerts endpoint"""
        self.client.get("/api/v1/alerts/unresolved", headers=self.headers)


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    print(f"\n{'='*60}")
    print(f"RCT-Engine Advanced Load Test Starting")
    print(f"Target: {environment.host}")
    print(f"Time: {datetime.now().isoformat()}")
    print(f"{'='*60}\n")


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    stats = environment.runner.stats.total
    print(f"\n{'='*60}")
    print(f"RCT-Engine Load Test Completed")
    print(f"{'='*60}")
    print(f"Total Requests: {stats.num_requests}")
    print(f"Failure Rate: {stats.fail_ratio * 100:.2f}%")
    print(f"Average Response Time: {stats.avg_response_time:.2f}ms")
    print(f"Min Response Time: {stats.min_response_time:.2f}ms")
    print(f"Max Response Time: {stats.max_response_time:.2f}ms")
    print(f"P50: {stats.get_response_time_percentile(0.5):.2f}ms")
    print(f"P90: {stats.get_response_time_percentile(0.9):.2f}ms")
    print(f"P95: {stats.get_response_time_percentile(0.95):.2f}ms")
    print(f"P99: {stats.get_response_time_percentile(0.99):.2f}ms")
    print(f"{'='*60}\n")
