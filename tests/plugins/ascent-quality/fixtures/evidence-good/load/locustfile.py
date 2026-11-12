"""Search: one request a second per user; users are set in locust.conf."""
from locust import HttpUser, task, constant_throughput, events


class Shopper(HttpUser):
    wait_time = constant_throughput(1)

    @task
    def search(self):
        self.client.get("/search?q=shoes")


@events.quitting.add_listener
def _(environment, **kw):
    if environment.stats.total.fail_ratio > 0.01:
        environment.process_exit_code = 1
    elif environment.stats.total.get_response_time_percentile(0.95) > 500:
        environment.process_exit_code = 1
