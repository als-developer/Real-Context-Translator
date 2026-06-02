from locust import HttpUser, task, between, events
import random
import json

class RCTEngineUser(HttpUser):
    wait_time = between(0.5, 2)
    
    def on_start(self):
        # Login and get API key
        response = self.client.post("/api/v1/auth/register", json={
            "email": f"test_{random.randint(1, 10000)}@test.com",
            "password": "test123",
            "full_name": "Test User",
            "organization_name": "Test Org"
        })
        
        if response.status_code == 200:
            self.api_key = response.json().get("api_key")
        else:
            # Use demo key if registration fails
            self.api_key = "demo_api_key"
    
    @task(3)
    def translate_simple(self):
        """Simple translation - high frequency"""
        self.client.post("/api/v1/translate", 
            json={
                "source_text": "Hello world, this is a test message",
                "source_language": "en",
                "target_country": "KE",
                "target_language": "sw"
            },
            headers={"X-API-Key": self.api_key}
        )
    
    @task(2)
    def translate_complex(self):
        """Complex translation with cultural context - medium frequency"""
        texts = [
            "Our company decided to reject the old offices",
            "The employee was caught stealing money",
            "This product is the best in the market",
            "We need to discuss the contract terms"
        ]
        
        countries = ["KE", "TZ", "SA", "CN", "NG"]
        
        self.client.post("/api/v1/translate",
            json={
                "source_text": random.choice(texts),
                "source_language": "en",
                "target_country": random.choice(countries),
                "target_language": "sw"
            },
            headers={"X-API-Key": self.api_key}
        )
    
    @task(1)
    def batch_translate(self):
        """Batch translation - low frequency"""
        batch = []
        for i in range(10):
            batch.append({
                "source_text": f"Test message {i}",
                "source_language": "en",
                "target_country": "KE",
                "target_language": "sw"
            })
        
        self.client.post("/api/v1/batch/translate",
            json={"texts": batch},
            headers={"X-API-Key": self.api_key}
        )
    
    @task(1)
    def get_analytics(self):
        """Analytics endpoint - low frequency"""
        self.client.get("/api/v1/analytics/dashboard",
            headers={"X-API-Key": self.api_key}
        )
    
    @task(1)
    def get_billing_info(self):
        """Billing endpoint - low frequency"""
        self.client.get("/api/v1/billing/plan",
            headers={"X-API-Key": self.api_key}
        )

@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    print("=== RCT-Engine Performance Test Starting ===")
    print(f"Target: {environment.host}")
    print(f"Users: {environment.runner.target_user_count}")

@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    print("=== RCT-Engine Performance Test Completed ===")
    stats = environment.runner.stats.total
    print(f"Total Requests: {stats.num_requests}")
    print(f"Failure Rate: {stats.fail_ratio * 100:.2f}%")
    print(f"Average Response Time: {stats.avg_response_time:.2f}ms")
    print(f"P95 Response Time: {stats.get_response_time_percentile(0.95):.2f}ms")
