# Load tests

The operator runs the browse and search tests before a release:

```bash
artillery run load/browse.yml
locust --config locust.conf
```
