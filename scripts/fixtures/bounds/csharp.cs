// META-ONLY fixture for security/bounds/csharp.yml (EVOL-106): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
using System;
using System.Net.Http;
using System.Threading;
using Amazon.S3;
using Azure.Storage.Blobs;

class HttpClients {
    void Build(HttpMessageHandler handler, TimeSpan configured) {
        // ruleid: csharp-httpclient-extract-deadline
        var a = new HttpClient { Timeout = TimeSpan.FromSeconds(10) };
        // ok: csharp-httpclient-extract-deadline
        var b = new HttpClient(handler) { Timeout = configured };
        // ruleid: csharp-httpclient-unbounded
        var c = new HttpClient();
        // ruleid: csharp-httpclient-unbounded
        var d = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
        // ok: csharp-httpclient-unbounded
        var e = new HttpClient(handler);
        // ruleid: csharp-httpclient-extract-deadline
        e.Timeout = TimeSpan.FromMilliseconds(2500);
        // ok: csharp-httpclient-unbounded
        HttpClient f = new HttpClient();
        // ok: csharp-httpclient-extract-deadline
        f.Timeout = configured;
    }
}

class AzureClients {
    void Build(int retries) {
        // ruleid: csharp-azure-extract-retries
        var a = new BlobClientOptions { Retry = { MaxRetries = 3, NetworkTimeout = TimeSpan.FromSeconds(20) } };
        // ok: csharp-azure-extract-retries
        var b = new BlobClientOptions { Retry = { MaxRetries = retries, NetworkTimeout = TimeSpan.FromSeconds(20) } };
        // ruleid: csharp-azure-unbounded
        var c = new BlobClientOptions { Retry = { MaxRetries = 3 } };
        // ruleid: csharp-azure-unbounded
        var d = new SecretClientOptions();
        // ok: csharp-azure-unbounded
        // ruleid: csharp-azure-extract-retries
        var o = new QueueClientOptions();
        o.Retry.NetworkTimeout = TimeSpan.FromSeconds(15);
        o.Retry.MaxRetries = 2;
    }
}

class AwsClients {
    private readonly AmazonS3Client _s3 = new AmazonS3Client(new AmazonS3Config { MaxErrorRetry = 3 });

    async void Call(GetObjectRequest req, PutObjectRequest put, CancellationToken token) {
        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(8));
        // ruleid: csharp-aws-extract-deadline
        await _s3.GetObjectAsync(req, cts.Token);
        // ruleid: csharp-aws-extract-deadline
        await _s3.PutObjectAsync(put, new CancellationTokenSource(TimeSpan.FromSeconds(4)).Token);
        // ok: csharp-aws-extract-deadline
        await _s3.PutObjectAsync(put, token);
        // ruleid: csharp-aws-unbounded
        await _s3.PutObjectAsync(put);
        // ruleid: csharp-aws-unbounded
        await _s3.ListBucketsAsync();
        // ruleid: csharp-aws-unbounded
        await _s3.GetObjectAsync(req, CancellationToken.None);
        // ok: csharp-aws-unbounded
        // ruleid: csharp-aws-extract-deadline
        await _s3.GetObjectAsync(req, cts.Token);
        // ok: csharp-aws-unbounded
        await _s3.PutObjectAsync(put, token);
    }
}
