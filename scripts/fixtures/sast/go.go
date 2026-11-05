// META-ONLY fixture for security/sast/go.yml (EVOL-074): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
package fixture

import (
	"context"
	"crypto/tls"
	"html/template"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/gin-gonic/gin"
	"github.com/labstack/echo/v4"
)

func debug() {
	// ruleid: go-debug-mode
	gin.SetMode(gin.DebugMode)
	// ok: go-debug-mode
	gin.SetMode(gin.ReleaseMode)
	e := echo.New()
	// ruleid: go-debug-mode
	e.Debug = true
	// ok: go-debug-mode
	e.Debug = false
}

func temp(data []byte) {
	// ruleid: go-insecure-temp-file
	f, _ := os.Create(filepath.Join(os.TempDir(), "report.txt"))
	// ruleid: go-insecure-temp-file
	g, _ := os.Create("/tmp/report.txt")
	// ok: go-insecure-temp-file
	h, _ := os.CreateTemp("", "report-*.txt")
	// ok: go-insecure-temp-file
	b, _ := os.ReadFile("/tmp/report.txt")
	// ok: go-insecure-temp-file
	defer os.RemoveAll(filepath.Join(os.TempDir(), "work"))
	// ruleid: go-insecure-temp-file
	_ = os.WriteFile("/tmp/report.txt", data, 0o600)
	_, _, _, _ = f, g, h, b
}

func html(userInput string) template.HTML {
	// ok: go-raw-html
	_ = template.HTML("<br>")
	// ruleid: go-raw-html
	return template.HTML(userInput)
}

func shell(userInput string) {
	// ruleid: go-shell-non-literal
	exec.Command("sh", "-c", "ls "+userInput).Run()
	// ok: go-shell-non-literal
	exec.Command("ls", userInput).Run()
	// ok: go-shell-non-literal
	exec.Command("sh", "-c", "date").Run()
	// ruleid: go-shell-non-literal
	exec.CommandContext(context.Background(), "bash", "-c", userInput).Run()
	// ok: go-shell-non-literal
	exec.CommandContext(context.Background(), "ls", userInput).Run()
}

func tlsConf() {
	// ruleid: go-tls-verify-disabled
	_ = &tls.Config{InsecureSkipVerify: true}
	// ok: go-tls-verify-disabled
	_ = &tls.Config{MinVersion: tls.VersionTLS12}
	cfg := &tls.Config{}
	// ruleid: go-tls-verify-disabled
	cfg.InsecureSkipVerify = true
	// ok: go-tls-verify-disabled
	cfg.InsecureSkipVerify = false
}
