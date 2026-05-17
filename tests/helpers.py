from __future__ import annotations
from dataclasses import dataclass
from typing import Literal
import requests

Environment = Literal["compose", "k8s"]

@dataclass(frozen=True)
class Endpoints:
    """Where to reach each component from the host (after port-forward
    or compose start)."""
    jaeger: str
    prometheus: str
    loki: str
    services: dict[str, str]   # name → base URL


def endpoints_for(env: Environment) -> Endpoints:
    if env == "k8s":
        # Same ports for both — port-forward maps them identically.
        return Endpoints(
            jaeger="http://localhost:16686",
            prometheus="http://localhost:9090",
            loki="http://localhost:3100",
            services={
                "csharp-service": "http://localhost:5001",
                "go-service":     "http://localhost:5002",
                "python-service": "http://localhost:5003",
                "rust-service":   "http://localhost:5004",
                "cpp-service":    "http://localhost:5005",
            },
        )
    # compose uses identical host port mapping by design
    return endpoints_for("k8s")


def jaeger_trace_count(jaeger_url: str, service: str, lookback: str = "10m") -> int:
    resp = requests.get(
        f"{jaeger_url}/api/traces",
        params={"service": service, "lookback": lookback, "limit": 20},
        timeout=5,
    )
    resp.raise_for_status()
    return len(resp.json().get("data") or [])
