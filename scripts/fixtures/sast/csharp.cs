// META-ONLY fixture for security/sast/csharp.yml (EVOL-074): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Http;
using Microsoft.AspNetCore.Html;

class Startup
{
    void Configure(IApplicationBuilder app, IWebHostEnvironment env)
    {
        if (env.IsDevelopment())
        {
            // ok: csharp-debug-mode
            app.UseDeveloperExceptionPage();
        }
        // ruleid: csharp-debug-mode
        app.UseDeveloperExceptionPage();
    }
}

class Fixture
{
    void Temp(string data)
    {
        // ruleid: csharp-insecure-temp-file
        File.WriteAllText(Path.Combine(Path.GetTempPath(), "report.txt"), data);
        // ok: csharp-insecure-temp-file
        File.WriteAllText(Path.Combine(Path.GetTempPath(), Path.GetRandomFileName()), data);
    }

    object Html(IHtmlHelper Html, string userInput)
    {
        // ruleid: csharp-raw-html
        var a = Html.Raw(userInput);
        // ok: csharp-raw-html
        var b = Html.Raw("<br>");
        // ruleid: csharp-raw-html
        var c = new HtmlString(userInput);
        return a;
    }

    void Shell(string userInput)
    {
        // ruleid: csharp-shell-non-literal
        Process.Start("bash", "-c \"ls " + userInput + "\"");
        // ok: csharp-shell-non-literal
        Process.Start("bash", "-c date");
        // ruleid: csharp-shell-non-literal
        var psi = new ProcessStartInfo("cmd.exe", "/c " + userInput);
        // ok: csharp-shell-non-literal
        var psi2 = new ProcessStartInfo("git", userInput);
        // ruleid: csharp-shell-non-literal
        var psi3 = new ProcessStartInfo { FileName = "/bin/bash", Arguments = "-c " + userInput };
        // ok: csharp-shell-non-literal
        var psi4 = new ProcessStartInfo { FileName = "/bin/bash", Arguments = "-c date" };
    }

    void Tls()
    {
        var handler = new HttpClientHandler();
        // ruleid: csharp-tls-verify-disabled
        handler.ServerCertificateCustomValidationCallback = (msg, cert, chain, errors) => true;
        // ok: csharp-tls-verify-disabled
        handler.ServerCertificateCustomValidationCallback = (msg, cert, chain, errors) => errors == System.Net.Security.SslPolicyErrors.None;
        // ruleid: csharp-tls-verify-disabled
        ServicePointManager.ServerCertificateValidationCallback += (sender, cert, chain, errors) => true;
        // ruleid: csharp-tls-verify-disabled
        handler.ServerCertificateCustomValidationCallback = HttpClientHandler.DangerousAcceptAnyServerCertificateValidator;
        // ruleid: csharp-tls-verify-disabled
        handler.ServerCertificateCustomValidationCallback = (msg, cert, chain, errors) => { return true; };
        // ruleid: csharp-tls-verify-disabled
        ServicePointManager.ServerCertificateValidationCallback = delegate { return true; };
    }
}
