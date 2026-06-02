#include <gtest/gtest.h>
#include "../backend/cpp_engine/lockfree_queue.hpp"
#include "../backend/cpp_engine/avx512_engine.cpp"

class LockFreeQueueTest : public ::testing::Test {
protected:
    LockFreeQueue<int, 1024> queue;
};

TEST_F(LockFreeQueueTest, PushPopSingleThread) {
    EXPECT_TRUE(queue.push(42));
    int value;
    EXPECT_TRUE(queue.pop(value));
    EXPECT_EQ(value, 42);
}

TEST_F(LockFreeQueueTest, QueueFull) {
    for (int i = 0; i < 1024; i++) {
        EXPECT_TRUE(queue.push(i));
    }
    EXPECT_FALSE(queue.push(1024));
}

TEST_F(LockFreeQueueTest, MultiThreadPushPop) {
    std::atomic<int> counter{0};
    std::thread producer([this, &counter]() {
        for (int i = 0; i < 1000; i++) {
            if (queue.push(i)) counter++;
        }
    });
    
    std::thread consumer([this, &counter]() {
        int value;
        for (int i = 0; i < 500; i++) {
            if (queue.pop(value)) counter--;
        }
    });
    
    producer.join();
    consumer.join();
    
    EXPECT_GE(counter.load(), 0);
}

class AVX512Test : public ::testing::Test {};

TEST_F(AVX512Test, RiskDetection) {
    alignas(64) float risk_array[16] = {
        0.1f, 0.2f, 0.3f, 0.4f,
        0.5f, 0.6f, 0.7f, 0.8f,
        0.9f, 0.95f, 0.1f, 0.2f,
        0.3f, 0.4f, 0.5f, 0.6f
    };
    
    bool breach = AVX512CulturalScanner::evaluate_risk_batch(risk_array, 0.75f);
    EXPECT_TRUE(breach);
    
    float max_risk = AVX512CulturalScanner::max_risk(risk_array);
    EXPECT_GT(max_risk, 0.9f);
}

TEST_F(AVX512Test, SafeContent) {
    alignas(64) float safe_array[16] = {
        0.01f, 0.02f, 0.03f, 0.04f,
        0.05f, 0.06f, 0.07f, 0.08f,
        0.09f, 0.10f, 0.11f, 0.12f,
        0.13f, 0.14f, 0.15f, 0.16f
    };
    
    bool breach = AVX512CulturalScanner::evaluate_risk_batch(safe_array, 0.75f);
    EXPECT_FALSE(breach);
}

int main(int argc, char **argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
