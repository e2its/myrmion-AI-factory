// META-ONLY fixture for security/sast/java.yml (EVOL-074): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
package fixture;

import java.io.File;
import java.nio.file.Files;
import java.security.cert.X509Certificate;
import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import javax.net.ssl.SSLSession;
import javax.net.ssl.X509TrustManager;
import org.apache.http.conn.ssl.NoopHostnameVerifier;
import org.apache.http.conn.ssl.SSLConnectionSocketFactory;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;

// ruleid: java-debug-mode
@EnableWebSecurity(debug = true)
class SecurityConfig {}

// ok: java-debug-mode
@EnableWebSecurity
class SecurityConfig2 {}

class Fixture {
    void temp() throws Exception {
        // ruleid: java-insecure-temp-file
        File f = File.createTempFile("report", ".txt");
        // ok: java-insecure-temp-file
        java.nio.file.Path p = Files.createTempFile("report", ".txt");
    }

    void shell(String userInput) throws Exception {
        // ruleid: java-shell-non-literal
        Runtime.getRuntime().exec("ls " + userInput);
        // ok: java-shell-non-literal
        Runtime.getRuntime().exec("date");
        // ruleid: java-shell-non-literal
        new ProcessBuilder("sh", "-c", userInput).start();
        // ok: java-shell-non-literal
        new ProcessBuilder("ls", userInput).start();
    }

    void tls() {
        // ruleid: java-tls-verify-disabled
        HttpsURLConnection.setDefaultHostnameVerifier((hostname, session) -> true);
        // ok: java-tls-verify-disabled
        HttpsURLConnection.setDefaultHostnameVerifier((hostname, session) -> hostname.equals("api.example.org"));
        // ruleid: java-tls-verify-disabled
        Object v = NoopHostnameVerifier.INSTANCE;
        // ok: java-tls-verify-disabled
        java.util.function.BiPredicate<String, String> any = (a, b) -> true;
        // ruleid: java-tls-verify-disabled
        okhttp3.OkHttpClient c = new okhttp3.OkHttpClient.Builder().hostnameVerifier((h, s) -> true).build();
        // ruleid: java-tls-verify-disabled
        SSLConnectionSocketFactory f = new SSLConnectionSocketFactory(ctx, (h, s) -> true);
        // ruleid: java-tls-verify-disabled
        HostnameVerifier held = (h, s) -> true;
        HostnameVerifier anon = new HostnameVerifier() {
            // ruleid: java-tls-verify-disabled
            public boolean verify(String h, SSLSession s) { return true; }
        };
        HostnameVerifier pinned = new HostnameVerifier() {
            // ok: java-tls-verify-disabled
            public boolean verify(String h, SSLSession s) { return h.equals("api.example.org"); }
        };
    }
}

class TrustAll implements X509TrustManager {
    public void checkClientTrusted(X509Certificate[] chain, String authType) {}
    // ruleid: java-tls-verify-disabled
    public void checkServerTrusted(X509Certificate[] chain, String authType) {}
    public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
}

class TrustChecked implements X509TrustManager {
    public void checkClientTrusted(X509Certificate[] chain, String authType) {}
    // ok: java-tls-verify-disabled
    public void checkServerTrusted(X509Certificate[] chain, String authType) { delegate(chain, authType); }
    public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
    void delegate(X509Certificate[] c, String a) {}
}
