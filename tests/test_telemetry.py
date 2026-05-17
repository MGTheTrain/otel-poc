from __future__ import annotations
import time
import pytest
from helpers import Endpoints, jaeger_trace_count


# Settle window before checking — OTel batch flush + scrape latency.
SETTLE_SECONDS = 30


@pytest.fixture(scope="module")
def traffic_generated(deployed_services: list[str], endpoints: Endpoints) -> None:
    """Hit each service N times, then wait for telemetry to settle."""
    import requests
    for _ in range(20):
        for name in deployed_services:
            try:
                requests.get(endpoints.services[name] + "/api/hello", timeout=2)
            except requests.RequestException:
                pass
    time.sleep(SETTLE_SECONDS)


def test_each_service_has_traces_in_jaeger(
    endpoints: Endpoints,
    deployed_services: list[str],
    traffic_generated: None,
) -> None:
    missing = []
    for name in deployed_services:
        n = jaeger_trace_count(endpoints.jaeger, name)
        if n == 0:
            missing.append(name)
    assert not missing, f"no traces in Jaeger for: {missing}"

@pytest.mark.skip(
    reason="TODO"
)
def test_each_service_has_metrics_in_prometheus(
    endpoints, deployed_services, traffic_generated
):
    ...


@pytest.mark.skip(
    reason="TODO"
)
def test_each_service_has_logs_in_loki(
    endpoints, deployed_services, traffic_generated
):
    ...
