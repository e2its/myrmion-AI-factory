# META-ONLY fixture for security/bounds/python.yml (EVOL-106): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
import os

import boto3
import httpx
import requests
from botocore.config import Config

T = float(os.environ.get("HTTP_TIMEOUT", "5"))
N = int(os.environ.get("AWS_ATTEMPTS", "3"))
url = "https://example.invalid"

# --- boto3 ---
# ruleid: python-boto3-unbounded
s3 = boto3.client("s3")
# ok: python-boto3-unbounded
s3 = boto3.client("s3", config=Config(connect_timeout=T, read_timeout=T, retries={"total_max_attempts": N}))
# ruleid: python-boto3-unbounded
cfg = Config(connect_timeout=2, retries={"total_max_attempts": 2})
# ruleid: python-boto3-unbounded
cfg = Config(connect_timeout=2, read_timeout=3, retries={"mode": "standard"})
# ruleid: python-boto3-unbounded
cfg = Config(read_timeout=3, connect_timeout=2)
# ok: python-boto3-unbounded
cfg = Config(read_timeout=3, connect_timeout=2, retries={"mode": "standard", "max_attempts": N})

# ruleid: python-boto3-extract-total
cfg = Config(read_timeout=3, connect_timeout=2, retries={"mode": "standard", "total_max_attempts": 3})
# ok: python-boto3-extract-total
cfg = Config(read_timeout=T, connect_timeout=2, retries={"total_max_attempts": 3})
# ok: python-boto3-extract-total
cfg = Config(read_timeout=3, connect_timeout=2, retries={"total_max_attempts": N})

# ruleid: python-boto3-extract-retries
cfg = Config(connect_timeout=2, read_timeout=3, retries={"max_attempts": 2})
# ok: python-boto3-extract-retries
cfg = Config(connect_timeout=2, read_timeout=3, retries={"max_attempts": N})
# total_max_attempts wins: the total rule, never the retries rule.
# ruleid: python-boto3-extract-total
cfg = Config(connect_timeout=2, read_timeout=3, retries={"max_attempts": 2, "total_max_attempts": 3})

# --- requests ---
# ruleid: python-requests-unbounded
r = requests.get(url)
# ruleid: python-requests-unbounded
r = requests.post(url, json={}, timeout=None)
# ruleid: python-requests-unbounded
r = requests.get(url, timeout=(3, None))
# ok: python-requests-unbounded
r = requests.get(url, timeout=T)
session = requests.Session()
# ruleid: python-requests-unbounded
r = session.get(url)
# ok: python-requests-unbounded
r = session.get(url, timeout=(T, T))
with requests.Session() as s:
    # ruleid: python-requests-unbounded
    s.put(url, data="x")

# ruleid: python-requests-extract-total
r = requests.get(url, timeout=(3.05, 27))
# ruleid: python-requests-extract-total
r = requests.request("GET", url, timeout=5)
# ruleid: python-requests-extract-total
r = session.post(url, timeout=10)
# ok: python-requests-extract-total
r = requests.get(url, timeout=(3, T))

# --- httpx ---
# ruleid: python-httpx-unbounded
c = httpx.Client()
# ruleid: python-httpx-unbounded
c = httpx.AsyncClient(timeout=None)
# ruleid: python-httpx-unbounded
r = httpx.get(url, timeout=httpx.Timeout(5.0, read=None))
# ok: python-httpx-unbounded
c = httpx.Client(timeout=T)

# ruleid: python-httpx-extract-total
c = httpx.Client(timeout=5.0)
# ruleid: python-httpx-extract-total
r = httpx.get(url, timeout=httpx.Timeout(10.0, connect=60.0))
# ruleid: python-httpx-extract-total
c = httpx.AsyncClient(timeout=httpx.Timeout(write=5, read=10, connect=2, pool=5))
# ok: python-httpx-extract-total
c = httpx.Client(timeout=httpx.Timeout(T))

# ruleid: python-httpx-extract-retries
c = httpx.Client(timeout=5.0, transport=httpx.HTTPTransport(retries=2))
# ruleid: python-httpx-extract-retries
c = httpx.AsyncClient(transport=httpx.AsyncHTTPTransport(retries=1), timeout=httpx.Timeout(10.0, connect=2.0))
# ok: python-httpx-extract-retries
c = httpx.Client(timeout=5.0, transport=httpx.HTTPTransport(retries=N))
