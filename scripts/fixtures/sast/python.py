# META-ONLY fixture for security/sast/python.yml (EVOL-074): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
import asyncio
import os
import ssl
import subprocess
import tempfile

import httpx
import jinja2
import requests
from django.utils.safestring import mark_safe
from flask import Flask

app = Flask(__name__)
user_input = os.environ.get("X", "")

# ruleid: python-debug-mode
app.run(host="0.0.0.0", debug=True)
# ok: python-debug-mode
app.run(host="0.0.0.0", debug=os.environ.get("APP_DEBUG") == "1")
# ruleid: python-debug-mode
DEBUG = True
# ok: python-debug-mode
DEBUG = os.environ.get("APP_DEBUG") == "1"
# ruleid: python-debug-mode
app.debug = True
# ruleid: python-debug-mode
app.config["DEBUG"] = True
# ok: python-debug-mode
app.config["DEBUG"] = False

# ruleid: python-insecure-temp-file
name = tempfile.mktemp()
# ok: python-insecure-temp-file
fd, name = tempfile.mkstemp()

# ruleid: python-autoescape-disabled
env = jinja2.Environment(autoescape=False)
# ok: python-autoescape-disabled
env = jinja2.Environment(autoescape=True)
# ruleid: python-autoescape-disabled
env = jinja2.Environment(loader=jinja2.FileSystemLoader("templates"))
# ok: python-autoescape-disabled
env = jinja2.Environment(loader=jinja2.FileSystemLoader("templates"), autoescape=jinja2.select_autoescape())
# ruleid: python-autoescape-disabled
html = mark_safe(user_input)
# ok: python-autoescape-disabled
html = mark_safe("<br>")

# ruleid: python-shell-non-literal
subprocess.run("ls " + user_input, shell=True)
# ok: python-shell-non-literal
subprocess.run(["ls", user_input])
# ok: python-shell-non-literal
subprocess.run("ls -l", shell=True)
# ruleid: python-shell-non-literal
os.system(f"rm {user_input}")
# ok: python-shell-non-literal
os.system("date")
# ruleid: python-shell-non-literal
out = subprocess.getoutput("ls " + user_input)
# ok: python-shell-non-literal
out = subprocess.getoutput("date")
# ruleid: python-shell-non-literal
proc = asyncio.create_subprocess_shell(user_input)
# ruleid: python-shell-non-literal
subprocess.run(args=user_input, shell=True)
# ok: python-shell-non-literal
subprocess.run(args="ls -l", shell=True)
# ruleid: python-shell-non-literal
subprocess.run(["sh", "-c", user_input])
# ok: python-shell-non-literal
subprocess.run(["sh", "-c", "date"])

# ruleid: python-tls-verify-disabled
requests.get("https://example.org", verify=False)
# ok: python-tls-verify-disabled
requests.get("https://example.org")
# ruleid: python-tls-verify-disabled
httpx.get("https://example.org", verify=False)
session = requests.Session()
# ruleid: python-tls-verify-disabled
session.get("https://example.org", verify=False)
# ruleid: python-tls-verify-disabled
session.verify = False
# ok: python-tls-verify-disabled
session.verify = "/etc/ssl/private-ca.pem"
# ruleid: python-tls-verify-disabled
ctx = ssl._create_unverified_context()
# ok: python-tls-verify-disabled
ctx = ssl.create_default_context()
# ruleid: python-tls-verify-disabled
ctx.verify_mode = ssl.CERT_NONE
# ok: python-tls-verify-disabled
ctx.verify_mode = ssl.CERT_REQUIRED
# ruleid: python-tls-verify-disabled
ctx.check_hostname = False
