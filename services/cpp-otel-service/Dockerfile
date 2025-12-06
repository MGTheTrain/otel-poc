FROM ubuntu:22.04 AS builder

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential \
    cmake \
    git \
    libcurl4-openssl-dev \
    libgrpc++-dev \
    libprotobuf-dev \
    protobuf-compiler-grpc \
    nlohmann-json3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install OpenTelemetry C++
WORKDIR /tmp
RUN git clone --depth 1 --branch v1.24.0 https://github.com/open-telemetry/opentelemetry-cpp.git && \
    cd opentelemetry-cpp && \
    mkdir build && cd build && \
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DWITH_OTLP_GRPC=ON \
        -DWITH_OTLP_HTTP=OFF \
        -DBUILD_TESTING=OFF \
        -DWITH_EXAMPLES=OFF && \
    cmake --build . --target install -j4

WORKDIR /app
COPY . .
RUN mkdir -p build && cd build && \
    cmake .. -DCMAKE_BUILD_TYPE=Release && \
    cmake --build . -j4

FROM ubuntu:22.04
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libgrpc++-dev \
    libprotobuf23 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /app/build/cpp-otel-service /app/
WORKDIR /app
EXPOSE 8080
ENV LD_LIBRARY_PATH=/usr/local/lib
CMD ["./cpp-otel-service"]
