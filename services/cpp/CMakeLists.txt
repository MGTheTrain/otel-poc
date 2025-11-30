cmake_minimum_required(VERSION 3.20)
project(cpp-otel-service)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find packages
find_package(CURL REQUIRED)
find_package(opentelemetry-cpp CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)

# Add executable
add_executable(cpp-otel-service main.cpp)

# Include cpp-httplib (header-only)
include(FetchContent)
FetchContent_Declare(
    httplib
    GIT_REPOSITORY https://github.com/yhirose/cpp-httplib.git
    GIT_TAG v0.14.3
)
FetchContent_MakeAvailable(httplib)

# Link libraries
target_link_libraries(cpp-otel-service
    PRIVATE
    opentelemetry-cpp::api
    opentelemetry-cpp::sdk
    opentelemetry-cpp::ext
    opentelemetry-cpp::exporters_otlp
    opentelemetry-cpp::logs
    opentelemetry-cpp::metrics
    opentelemetry-cpp::trace
    nlohmann_json::nlohmann_json
    httplib::httplib
    CURL::libcurl
)
