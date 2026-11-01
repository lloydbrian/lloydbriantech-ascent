import requests


def send(url, body):
    return requests.post(url, json=body, timeout=5)
