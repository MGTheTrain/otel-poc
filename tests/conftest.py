from __future__ import annotations
import pytest
from helpers import Endpoints, endpoints_for


def pytest_addoption(parser: pytest.Parser) -> None:
    parser.addoption(
        "--env",
        action="store",
        default="k8s",
        choices=["compose", "k8s"],
        help="Target environment.",
    )


@pytest.fixture(scope="session")
def endpoints(pytestconfig: pytest.Config) -> Endpoints:
    return endpoints_for(pytestconfig.getoption("--env"))


@pytest.fixture(scope="session")
def deployed_services(endpoints: Endpoints) -> list[str]:
    """Probe each candidate service; return only the ones responding."""
    import requests
    alive = []
    for name, url in endpoints.services.items():
        try:
            r = requests.get(f"{url}/api/hello", timeout=2)
            if r.status_code == 200:
                alive.append(name)
        except requests.RequestException:
            pass
    if not alive:
        pytest.exit("No services reachable — did you run port-forward / compose-start?", returncode=2)
    return alive
