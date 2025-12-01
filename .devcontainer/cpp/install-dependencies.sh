#!/bin/bash

sudo apt-get update 
sudo apt-get install -y \
    cmake build-essential libcurl4-openssl-dev libgrpc++-dev \
    libprotobuf-dev protobuf-compiler-grpc nlohmann-json3-dev

cd /tmp
git clone --depth 1 --branch v1.24.0 https://github.com/open-telemetry/opentelemetry-cpp.git
cd opentelemetry-cpp
mkdir build 
cd build
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_OTLP_GRPC=ON \
    -DWITH_OTLP_HTTP=OFF \
    -DBUILD_TESTING=OFF \
    -DWITH_EXAMPLES=OFF
cmake --build . --target install -j4