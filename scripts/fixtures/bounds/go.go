// META-ONLY fixture for security/bounds/go.yml (EVOL-106): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
package fixture

import (
	"net/http"
	"net/url"
	"time"
)

func unbounded(cfg time.Duration, t http.RoundTripper) {
	// ruleid: go-nethttp-unbounded
	bare := &http.Client{}
	// ruleid: go-nethttp-unbounded
	transportOnly := http.Client{Transport: t}
	// ok: go-nethttp-unbounded
	fromConfig := &http.Client{Timeout: cfg}
	// ok: go-nethttp-unbounded
	later := &http.Client{Transport: t}
	later.Timeout = cfg
	// ruleid: go-nethttp-unbounded
	http.Get("https://x")
	// ruleid: go-nethttp-unbounded
	http.Post("https://x", "text/plain", nil)
	// ruleid: go-nethttp-unbounded
	http.PostForm("https://x", url.Values{})
	// ruleid: go-nethttp-unbounded
	http.DefaultClient.Do(nil)
	// ok: go-nethttp-unbounded
	fromConfig.Get("https://x")
	_, _, _, _ = bare, transportOnly, fromConfig, later
}

func deadlines(cfg time.Duration) {
	// ruleid: go-nethttp-extract-deadline
	a := &http.Client{Timeout: 10 * time.Second}
	// ruleid: go-nethttp-extract-deadline
	b := http.Client{Timeout: 2500 * time.Millisecond}
	c := &http.Client{}
	// ruleid: go-nethttp-extract-deadline
	c.Timeout = 2 * time.Minute
	// ok: go-nethttp-extract-deadline
	d := &http.Client{Timeout: cfg}
	// ok: go-nethttp-extract-deadline
	e := &http.Client{Timeout: 1 * time.Hour}
	_, _, _, _, _ = a, b, c, d, e
}
