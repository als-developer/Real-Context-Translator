# Multi-stage build for C++ AVX-512 Engine
# Stage 1: Builder
FROM gcc:13.2 AS builder

WORKDIR /build

# Copy C++ source files
COPY backend/cpp_engine/*.cpp .
COPY backend/cpp_engine/*.hpp .

# Compile with aggressive optimizations
RUN g++ -O3 -std=c++23 -march=native -mavx512f -mavx512dq \
    -pthread -flto -fno-exceptions -fno-rtti \
    -o rct_core rct_core.cpp

# Stage 2: Minimal runtime
FROM alpine:3.23

RUN apk add --no-cache libstdc++

COPY --from=builder /build/rct_core /usr/local/bin/rct_core

EXPOSE 9000

CMD ["/usr/local/bin/rct_core"]
