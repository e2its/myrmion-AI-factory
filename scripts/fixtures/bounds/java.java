// META-ONLY fixture for security/bounds/java.yml (EVOL-106): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
package fixture;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.time.Duration;
import software.amazon.awssdk.core.client.config.ClientOverrideConfiguration;
import software.amazon.awssdk.services.s3.S3Client;

class AwsClients {
    void clients(Duration cfg, int attempts) {
        // ruleid: java-aws-unbounded
        S3Client bare = S3Client.builder().region(null).build();
        // ok: java-aws-unbounded
        S3Client tuned = S3Client.builder().overrideConfiguration(cfg()).build();

        // ruleid: java-aws-unbounded
        ClientOverrideConfiguration none = ClientOverrideConfiguration.builder().build();
        // ruleid: java-aws-unbounded
        ClientOverrideConfiguration attemptOnly = ClientOverrideConfiguration.builder().apiCallAttemptTimeout(cfg).build();
        // ok: java-aws-unbounded
        ClientOverrideConfiguration fromConfig = ClientOverrideConfiguration.builder().apiCallTimeout(cfg).build();
        // ok: java-aws-unbounded
        ClientOverrideConfiguration perAttemptVar = ClientOverrideConfiguration.builder().retryStrategy(b -> b.maxAttempts(attempts)).apiCallAttemptTimeout(cfg).build();
    }

    void deadlines(Duration cfg) {
        // ruleid: java-aws-extract-deadline
        ClientOverrideConfiguration d = ClientOverrideConfiguration.builder().apiCallTimeout(Duration.ofSeconds(25)).build();
        // ok: java-aws-extract-deadline
        ClientOverrideConfiguration v = ClientOverrideConfiguration.builder().apiCallTimeout(cfg).build();
        // ok: java-aws-extract-deadline
        ClientOverrideConfiguration h = ClientOverrideConfiguration.builder().apiCallTimeout(Duration.ofHours(1)).build();
    }

    void attempts(Duration cfg, int n) {
        // ruleid: java-aws-extract-total
        ClientOverrideConfiguration a = ClientOverrideConfiguration.builder().apiCallAttemptTimeout(Duration.ofMillis(2000)).retryStrategy(b -> b.maxAttempts(3)).build();
        // ruleid: java-aws-extract-total
        ClientOverrideConfiguration b2 = ClientOverrideConfiguration.builder().retryStrategy(r -> r.maxAttempts(2)).apiCallAttemptTimeout(Duration.ofSeconds(4)).build();
        // ok: java-aws-extract-total
        ClientOverrideConfiguration partial = ClientOverrideConfiguration.builder().apiCallAttemptTimeout(Duration.ofSeconds(4)).retryStrategy(r -> r.maxAttempts(n)).build();
    }
}

class LocalHttp {
    void call(Duration cfg) {
        HttpClient client = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(3)).build();
        // ruleid: java-httpclient-extract-total
        HttpRequest r1 = HttpRequest.newBuilder(URI.create("https://x")).timeout(Duration.ofSeconds(10)).build();
        // ok: java-httpclient-extract-total
        HttpRequest r2 = HttpRequest.newBuilder(URI.create("https://x")).timeout(cfg).build();
    }

    void unbounded(Duration cfg) {
        // ruleid: java-httpclient-unbounded
        HttpClient c1 = HttpClient.newHttpClient();
        // ruleid: java-httpclient-unbounded
        HttpClient c2 = HttpClient.newBuilder().followRedirects(HttpClient.Redirect.NORMAL).build();
        // ok: java-httpclient-unbounded
        HttpClient c3 = HttpClient.newBuilder().connectTimeout(cfg).build();
        // ruleid: java-httpclient-unbounded
        HttpRequest r3 = HttpRequest.newBuilder().uri(URI.create("https://x")).GET().build();
        // ok: java-httpclient-unbounded
        HttpRequest r4 = HttpRequest.newBuilder().uri(URI.create("https://x")).timeout(cfg).build();
    }
}

class FieldHttp {
    private static final HttpClient CLIENT = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();

    void call(Duration cfg) {
        // ruleid: java-httpclient-extract-total
        HttpRequest r = HttpRequest.newBuilder().uri(URI.create("https://x")).timeout(Duration.ofMillis(5000)).build();
    }
}

class VarConnectHttp {
    void call(Duration cfg) {
        HttpClient client = HttpClient.newBuilder().connectTimeout(cfg).build();
        // ok: java-httpclient-extract-total
        HttpRequest r = HttpRequest.newBuilder().uri(URI.create("https://x")).timeout(Duration.ofSeconds(10)).build();
    }
}
