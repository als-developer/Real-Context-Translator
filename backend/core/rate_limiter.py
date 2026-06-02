import time
from collections import defaultdict
from threading import Lock
from typing import Dict, Tuple

class TokenBucketRateLimiter:
    def __init__(self, rate: int = 50, capacity: int = 100):
        self.rate = rate  # tokens per second
        self.capacity = capacity
        self.tokens: Dict[str, float] = defaultdict(lambda: capacity)
        self.last_refill: Dict[str, float] = defaultdict(time.time)
        self.lock = Lock()
    
    def is_allowed(self, key: str) -> Tuple[bool, int]:
        with self.lock:
            now = time.time()
            last = self.last_refill[key]
            elapsed = now - last
            
            # Refill tokens
            self.tokens[key] = min(self.capacity, self.tokens[key] + elapsed * self.rate)
            self.last_refill[key] = now
            
            if self.tokens[key] >= 1:
                self.tokens[key] -= 1
                return True, int(self.tokens[key])
            else:
                wait_time = (1 - self.tokens[key]) / self.rate
                return False, int(wait_time * 1000)

class DistributedRateLimiter:
    """Redis-based rate limiter for multi-node deployment"""
    def __init__(self, redis_client):
        self.redis = redis_client
    
    async def is_allowed(self, key: str, limit: int = 50, window: int = 1) -> bool:
        """Sliding window rate limiter"""
        current = await self.redis.get(key)
        if current is None:
            await self.redis.setex(key, window, 1)
            return True
        
        count = int(current)
        if count < limit:
            await self.redis.incr(key)
            return True
        return False

rate_limiter = TokenBucketRateLimiter(rate=50, capacity=100)
