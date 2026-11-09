// META-ONLY fixture for security/bounds/javascript.yml (EVOL-106): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { DynamoDBClient as Ddb } from "@aws-sdk/client-dynamodb";
import { NodeHttpHandler } from "@smithy/node-http-handler";
import { BlobServiceClient, ContainerClient, StorageSharedKeyCredential } from "@azure/storage-blob";
import { ApolloClient } from "@apollo/client";
import axios from "axios";
const { SQSClient } = require("@aws-sdk/client-sqs");

const T = Number(process.env.HTTP_TIMEOUT_MS ?? "3000");
const N = Number(process.env.ATTEMPTS ?? "3");
const url = "https://example.invalid";
const cred = new StorageSharedKeyCredential("acct", "key");
const pipeline = cred;

// --- AWS SDK v3 ---
// ruleid: javascript-aws-unbounded
const a1 = new S3Client();
// ruleid: javascript-aws-unbounded
const a2 = new S3Client({ region: "eu-west-1" });
// ruleid: javascript-aws-unbounded
const a3 = new SQSClient({ maxAttempts: 2, requestHandler: { connectionTimeout: 1000, requestTimeout: 3000 } });
// ruleid: javascript-aws-unbounded
const a4 = new Ddb({ requestHandler: new NodeHttpHandler({ connectionTimeout: 1000, requestTimeout: 3000, throwOnRequestTimeout: true }) });
// ruleid: javascript-aws-unbounded
const a5 = new S3Client({ maxAttempts: 2, requestHandler: { requestTimeout: 3000, throwOnRequestTimeout: true } });
// ok: javascript-aws-unbounded
const a6 = new S3Client({ maxAttempts: N, requestHandler: { connectionTimeout: T, requestTimeout: T, throwOnRequestTimeout: true } });
// ok: javascript-aws-unbounded
const a7 = new ApolloClient({});
// ok: javascript-aws-unbounded
const a8 = new GetObjectCommand({ Bucket: "b", Key: "k" });

// ruleid: javascript-aws-extract-total
const e1 = new S3Client({ requestHandler: { requestTimeout: 3000, throwOnRequestTimeout: true, connectionTimeout: 1000 }, maxAttempts: 2 });
// ruleid: javascript-aws-extract-total
const e2 = new Ddb({ maxAttempts: 3, requestHandler: new NodeHttpHandler({ connectionTimeout: 500, requestTimeout: 2000, throwOnRequestTimeout: true }) });
// ok: javascript-aws-extract-total
const e3 = new S3Client({ maxAttempts: N, requestHandler: { connectionTimeout: 1000, requestTimeout: 3000, throwOnRequestTimeout: true } });

// --- axios ---
// ruleid: javascript-axios-unbounded
const x1 = axios.create();
// ruleid: javascript-axios-unbounded
const x2 = axios.create({ baseURL: url });
// ruleid: javascript-axios-unbounded
const x3 = axios.create({ baseURL: url, timeout: 0 });
// ruleid: javascript-axios-unbounded
axios.get(url);
// ruleid: javascript-axios-unbounded
axios.post(url, { name: "n" });
// ruleid: javascript-axios-unbounded
axios.get(url, { headers: {} });
// ruleid: javascript-axios-unbounded
axios.put(url, { name: "n" }, { headers: {} });
// ruleid: javascript-axios-unbounded
axios({ method: "get", url });
// ruleid: javascript-axios-unbounded
axios(url);
// ok: javascript-axios-unbounded
const x4 = axios.create({ baseURL: url, timeout: T });
// ok: javascript-axios-unbounded
axios.post(url, { name: "n" }, { timeout: T });

// ruleid: javascript-axios-extract-deadline
const d1 = axios.create({ baseURL: url, timeout: 2500 });
// ruleid: javascript-axios-extract-deadline
axios.get(url, { timeout: 1000 });
// ruleid: javascript-axios-extract-deadline
axios.patch(url, { name: "n" }, { timeout: 1500 });
// ruleid: javascript-axios-extract-deadline
axios.request({ url, timeout: 4000 });
// ok: javascript-axios-extract-deadline
axios.get(url, { timeout: T });
// ok: javascript-axios-extract-deadline
axios.post(url, { timeout: 5 }, { timeout: T });

// --- fetch ---
// ruleid: javascript-fetch-unbounded
fetch(url);
// ruleid: javascript-fetch-unbounded
fetch(url, { method: "POST" });
// ok: javascript-fetch-unbounded
fetch(url, { signal: AbortSignal.timeout(T) });
// ok: javascript-fetch-unbounded
fetch(new Request(url, { signal: AbortSignal.timeout(T) }));

// ruleid: javascript-fetch-extract-deadline
fetch(url, { method: "GET", signal: AbortSignal.timeout(5000) });
// ok: javascript-fetch-extract-deadline
fetch(url, { signal: AbortSignal.timeout(T) });

// --- Azure Storage ---
// ruleid: javascript-azure-storage-unbounded
const b1 = new BlobServiceClient(url);
// ruleid: javascript-azure-storage-unbounded
const b2 = new BlobServiceClient(url, new StorageSharedKeyCredential("acct", "key"));
// ruleid: javascript-azure-storage-unbounded
const b3 = new BlobServiceClient(url, cred, { retryOptions: { maxTries: 3 } });
// ruleid: javascript-azure-storage-unbounded
const b4 = new ContainerClient(url, "container", { retryOptions: { tryTimeoutInMs: 5000 } });
// ok: javascript-azure-storage-unbounded
const b5 = new BlobServiceClient(url, cred, { retryOptions: { maxTries: N, tryTimeoutInMs: T } });
// ok: javascript-azure-storage-unbounded
const b6 = new BlobServiceClient(url, pipeline);

// ruleid: javascript-azure-storage-extract-total
const s1 = new BlobServiceClient(url, cred, { retryOptions: { tryTimeoutInMs: 5000, maxTries: 3 } });
// ok: javascript-azure-storage-extract-total
const s2 = new BlobServiceClient(url, cred, { retryOptions: { tryTimeoutInMs: T, maxTries: 3 } });
