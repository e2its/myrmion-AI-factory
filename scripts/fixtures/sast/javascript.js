// META-ONLY fixture for security/sast/javascript.yml (EVOL-074): every rule fires on a `ruleid:` line, stays quiet on an `ok:` line.
import { exec } from 'node:child_process';
const child_process = require('child_process');
const cp = require('node:child_process');
const { execSync } = require('child_process');
import { spawn } from 'node:child_process';
import * as cpx from 'child_process';
const ncp = require('node:child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const { ApolloServer } = require('apollo-server');
const Handlebars = require('handlebars');

const userInput = process.argv[2];

// ruleid: javascript-debug-mode
const server = new ApolloServer({ typeDefs, resolvers, debug: true });
// ok: javascript-debug-mode
const server2 = new ApolloServer({ typeDefs, resolvers, debug: process.env.APP_DEBUG === '1' });
// ruleid: javascript-debug-mode
process.env.NODE_ENV = "development";
// ok: javascript-debug-mode
process.env.NODE_ENV = "production";

// ruleid: javascript-insecure-temp-file
fs.writeFileSync(path.join(os.tmpdir(), 'report.txt'), userInput);
// ruleid: javascript-insecure-temp-file
fs.writeFileSync(os.tmpdir() + '/report.txt', userInput);
// ok: javascript-insecure-temp-file
const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'report-'));
// ok: javascript-insecure-temp-file
fs.writeFileSync(path.join(dir, 'report.txt'), userInput);

// ruleid: javascript-raw-html
document.getElementById('out').innerHTML = userInput;
// ok: javascript-raw-html
document.getElementById('out').textContent = userInput;
// ok: javascript-raw-html
document.getElementById('out').innerHTML = "";
// ruleid: javascript-raw-html
document.getElementById('out').innerHTML += userInput;
// ruleid: javascript-raw-html
document.getElementById('out').insertAdjacentHTML('beforeend', userInput);
// ok: javascript-raw-html
document.getElementById('out').insertAdjacentHTML('beforeend', '<hr>');
// ruleid: javascript-raw-html
document.write(userInput);
// ruleid: javascript-raw-html
const t = Handlebars.compile(src, { noEscape: true });
// ok: javascript-raw-html
const t2 = Handlebars.compile(src);

// ruleid: javascript-shell-non-literal
child_process.exec('ls ' + userInput);
// ok: javascript-shell-non-literal
child_process.execFile('ls', [userInput]);
// ok: javascript-shell-non-literal
child_process.exec('date');
// ruleid: javascript-shell-non-literal
require('child_process').execSync(`rm ${userInput}`);
// ruleid: javascript-shell-non-literal
child_process.spawn('ls', [userInput], { shell: true });
// ok: javascript-shell-non-literal
child_process.spawn('ls', [userInput]);
// ruleid: javascript-shell-non-literal
child_process.spawnSync(userInput, { shell: true });
// ruleid: javascript-shell-non-literal
exec('ls ' + userInput);
// ruleid: javascript-shell-non-literal
cp.exec('ls ' + userInput);
// ruleid: javascript-shell-non-literal
execSync('ls ' + userInput);
// ok: javascript-shell-non-literal
cp.exec('date');
// ruleid: javascript-shell-non-literal
spawn(userInput, { shell: true });
// ruleid: javascript-shell-non-literal
ncp.spawn('ls', [userInput], { shell: true });
// ruleid: javascript-shell-non-literal
require('node:child_process').execFile(userInput, { shell: true });
// ruleid: javascript-shell-non-literal
cpx.exec('ls ' + userInput);
// ok: javascript-shell-non-literal
ncp.spawn('ls', [userInput]);

// ruleid: javascript-tls-verify-disabled
const agent = new https.Agent({ rejectUnauthorized: false });
// ok: javascript-tls-verify-disabled
const agent2 = new https.Agent({ rejectUnauthorized: true });
// ruleid: javascript-tls-verify-disabled
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
