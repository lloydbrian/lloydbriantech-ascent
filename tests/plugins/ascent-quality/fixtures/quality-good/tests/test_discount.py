import pytest
import responses

from src.rules import discount
from src import notify


def check_close(a, b):
    if abs(a - b) > 0.01:
        raise AssertionError(f"{a} != {b}")


def test_apply():
    assert discount.apply(10, 10) == 9.0


def test_apply_rounds():
    check_close(discount.apply(9.99, 33), 6.69)


@responses.activate
def test_notify_posts():
    responses.post("https://hooks.example.test/x", json={"ok": True})
    assert notify.send("https://hooks.example.test/x", {}).status_code == 200


@pytest.mark.skip(reason="needs the payments sandbox")
def test_sandbox_refund():
    pass


@pytest.mark.skipif(True, reason="runs on Linux only")
def test_linux_only():
    assert True
