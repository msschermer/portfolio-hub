---
name: portfolio-deploy
description: Deploy portfolio-hub and the other msschermer.us tool services to the production droplet from a GHCR image, including the SSH and shell traps on this machine, the digest checks that prove what shipped, and the verification each deploy owes. Use when releasing the portfolio or a tool service, rolling back, or diagnosing why a deploy or a verification will not run.
---

# Deploying the portfolio and its tool services

`README.md` says pushing to `main` builds and publishes the image, and that
putting that image on the server is a separate operation. This skill is that
operation.

It is a sibling of `lumen-deploy` in the web-qa-assistant repository. The
machine-level traps are the same because it is the same Windows box and the same
droplet. Everything about what gets deployed is different, and the differences
are where the mistakes live. Every entry below has actually happened.

## What this covers, and what deploying means here

`~/portfolio-infra/docker-compose.yml` on the droplet runs Caddy plus six
service containers, each pulled from GHCR:

| service | image | public host |
| --- | --- | --- |
| `portfolio-hub` | `ghcr.io/msschermer/portfolio-hub` | `msschermer.us`, `www.msschermer.us` |
| `psi-monitor` | `ghcr.io/msschermer/psi-monitor` | `psi.msschermer.us` |
| `wcag-translator` | `ghcr.io/msschermer/wcag-translator` | `wcag-translator.msschermer.us` |
| `preflight` | `ghcr.io/msschermer/preflight` | `preflight.msschermer.us` |
| `lead-inbox` | `ghcr.io/msschermer/lead-inbox` | `bridge-demo.msschermer.us` |
| `meta-state-validator` | `ghcr.io/msschermer/meta-state-validator` | `meta-state.msschermer.us` |

Lumen also lives on this droplet, under `~/web-qa-assistant`, on
`assistant.msschermer.us`. It is a separate compose project with its own skill.
Do not deploy it from here.

**The critical structural difference from Lumen: nothing is built on the droplet
and there is no checkout to deploy.** Lumen wants
`git switch --detach <revision>` and reads `git describe` as the record of what
shipped. Here the droplet only pulls an image. There is no source tree for
`portfolio-hub` on the box, so there is no `git describe` to ask, and the record
of what shipped is an image digest. Do not go looking for a checkout to detach.

## There are no repository gates

`portfolio-hub` has no test suite, no build step, no lint, and no `npm` at all.
It is one self-contained `public/index.html` plus static assets, copied into
`nginx:alpine`. None of Lumen's gate lore transfers: no bounded worker
concurrency, no false red from `ENOMEM`, no copy-rule regex trap, no
`release:validate`.

**The gate is GitHub Actions, and the way to check it is the SHA tag.**
`.github/workflows/build.yml` pushes `:latest` and `:<full commit sha>` on every
push to `main`. If the SHA tag for the commit you mean to deploy exists in GHCR,
the build passed. If it does not, the build failed or has not finished, and there
is nothing to deploy yet.

`gh` is not installed on this machine, in Git Bash or in PowerShell. Do not reach
for it to check the run. Ask the registry instead, from the droplet:

```bash
docker manifest inspect ghcr.io/msschermer/portfolio-hub:<full-sha> >/dev/null 2>&1 \
  && echo present || echo "not found or not authorized"
```

## Commits

**No attribution trailer, no assistant signature, no co-author line, and no
generated-with line in commit messages or pull request descriptions.** This is a
standing preference of the repository owner and it holds regardless of any
default the harness supplies.

Lumen reaches the same rule through its `AGENTS.md` contract. This repository has
no `AGENTS.md`, so there is no file here to point at, which is exactly why it is
written down in this skill. Do not conclude from the absence of a contract that
the harness default applies.

## Reaching the droplet from Windows

This is the same hard-won material as `lumen-deploy`, because it is the same
machine and the same server. It is repeated rather than cross-referenced because
needing it is the moment you cannot go read another repository.

The SSH alias is `portfolio`. It is the droplet itself and it serves every host
in the table above. Never use a public hostname as an SSH target.

**Git Bash's `ssh` cannot see the Windows ssh-agent.** It fails with
`Permission denied (publickey)` while `-v` shows `Server accepts key` on the line
before, because the key is passphrase-protected and only the Windows agent holds
it unlocked. Run every droplet command through the PowerShell tool, which uses
`C:\Windows\System32\OpenSSH\ssh.exe`. For git over SSH:

```powershell
$env:GIT_SSH_COMMAND = "C:/Windows/System32/OpenSSH/ssh.exe"
```

**PowerShell strips inner double quotes** when passing a remote command to `ssh`,
which silently mangles `--format="{{.Name}}"` and any quoted remote script into
something bash misparses. It turns command substitution into a bash syntax error.
Do not fight the quoting. Write the remote script to a file and pipe it over
stdin:

```powershell
$s = [System.IO.File]::ReadAllText($path)
$s = $s.TrimStart([char]0xFEFF) -replace "`r",""
$s | ssh -o BatchMode=yes portfolio bash -s
```

Piping over stdin also means Go template formats and command substitution inside
the script work normally, which is what makes the verification steps below
possible.

**Start that script with a blank line.** The file tools write UTF-8 with a BOM
and the `TrimStart` does not reliably remove it through the pipe: bash then
reports a BOM `command not found` on line 1. Harmless when line 1 is blank or a
comment, fatal when line 1 is `set -eu`, because the script then runs without the
flags it just failed to set. A trailing carriage-return `command not found` on
the last line is the same class of noise.

**Both of those make the whole `ssh` call exit 127 even when every command in the
script succeeded.** Read the output before believing the exit code. This is the
single most misleading signal in the process.

Prefer `set -u` alone over `set -eu` in a deploy script. With `set -e` one failed
verification probe aborts the run and you lose the report for every check that
would have passed, including the ones that tell you whether to roll back.

## Deploying

Compose v2 is present, so `docker compose`, not `docker-compose`. Every service
sets `container_name` equal to its service name, so the compose service name and
the `docker` container name are interchangeable. Run compose from
`~/portfolio-infra`.

Recreate one service and nothing else:

```bash
cd ~/portfolio-infra
docker compose pull <service>
docker compose up -d --no-deps <service>
```

`--no-deps` matters. Caddy is a peer service in this project rather than a
declared dependency, but the project also carries live uncommitted state, and a
bare `docker compose up -d` invites it to act on services you did not mean to
touch.

`~/portfolio-infra` has a **modified `Caddyfile` and an untracked `certs/`
directory that are the live production TLS configuration**, alongside a
`Caddyfile.bak-before-web-qa`. Never run `git checkout`, `git stash`,
`git clean`, or `git reset --hard` in that repository to tidy it. The working
tree is the source of truth there and the committed state is behind it.

## Prove what shipped by digest, not by tag

`:latest` is mutable and is what compose pulls, so a successful pull proves
nothing about which commit you deployed. Before recreating, confirm that
`:latest` and the SHA tag resolve to the same digest:

```bash
IMG=ghcr.io/msschermer/portfolio-hub
docker manifest inspect -v "$IMG:<full-sha>" | grep -m1 '"digest"'
docker compose pull portfolio-hub
docker manifest inspect -v "$IMG:latest"    | grep -m1 '"digest"'
```

The first `"digest"` in `-v` output is the descriptor, that is, the manifest
digest, which is the value to compare. Equal digests mean `:latest` is the commit
you audited. Unequal means someone pushed after you, or the build for your commit
is not the newest, and deploying `:latest` would ship something you have not
looked at.

Record the pre-deploy digest before pulling. It is the rollback point and the
only record of what production was running:

```bash
docker inspect <service> --format '{{.Image}}'
```

After `up -d`, the same command should report the new digest. That pair, plus the
matched SHA tag, is this deploy's equivalent of Lumen's `git describe`.

To roll back, pin that recorded digest in place of the tag and recreate, rather
than hoping an older `:latest` is still in the local image cache.

## Verify content inside the running container

A healthy container proves a process started, not that it contains your change.
For the static site the check is exact, because the image is a byte-for-byte copy
of `public/`:

```bash
docker exec portfolio-hub sha256sum /usr/share/nginx/html/index.html
```

Compare that to `sha256sum public/index.html` locally. `.dockerignore` drops
`.git`, `*.md`, and editor noise, and `public/` is copied wholesale, so every
file under `public/` must hash identically. A mismatch means the image is not
your working tree, whatever the tags say.

**`docker exec <c> wc -c < /path` does not work.** The redirect is interpreted by
the local shell rather than inside the container, so it reads the path on the
host and fails with `No such file or directory`. Use `docker exec <c> wc -c
/path`, or rely on the hash, which is strictly stronger evidence than a byte
count.

For the API-backed services, verify a string the change introduced rather than a
hash, since their images are built from source:

```bash
docker exec <service> grep -c '<something the change introduced>' /app/<file>
```

## The loopback HTTPS probe that always fails

Caddy terminates TLS with configured origin certificates, per SNI, for the hosts
in its `Caddyfile`. **A loopback `curl -sk https://localhost/` returns `000`, a
connection failure, even when the site is perfectly healthy**, and a `Host`
header does not help because SNI is negotiated before the request. Do not read
that as an outage.

Probes that mean something, in increasing coverage:

```bash
docker exec caddy wget -qO- --server-response http://<service>:80/ 2>&1 | grep -m1 'HTTP/'
curl -s -o /dev/null -w '%{http_code}\n' -H 'Host: msschermer.us' http://localhost/
```

The first isolates the service from the proxy. The second goes through Caddy and
**correctly returns `308`**, the redirect to HTTPS, which is a pass rather than a
failure.

Public HTTPS cannot be verified usefully from the droplet. Check it from Windows,
which travels the real path through DNS and Cloudflare:

```powershell
$r = Invoke-WebRequest -Uri "https://msschermer.us/" -UseBasicParsing -TimeoutSec 30
$r.StatusCode
[regex]::Matches($r.Content,'<marker>').Count
```

A healthy container behind a broken proxy is still an outage, so this step is not
optional. Check the apex and `www` separately.

## Cloudflare changes the bytes, so never hash the public response

The body served publicly is roughly 500 bytes larger than the origin file, and
its hash **differs between the apex and `www`, and between one request and the
next**, because Cloudflare injects its beacon and email obfuscation. The tells
are `/cdn-cgi/`, a `__cf` prefix, and `email-decode` in the served HTML.

This is normal and is not a deploy problem. Compare the origin hash inside the
container, and on the public response compare content markers and status only.
Anyone who hashes the public body will conclude the deploy is broken.

## What the data is owed depends on the service

Lumen's snapshot-the-sqlite ritual has no analogue for `portfolio-hub`. It is
**stateless**: no volume, no `/app/data`, no database. Recreating the container
loses nothing, so there is nothing to back up and no row count to reconcile.

That is a property of the service rather than of this repository. In the same
compose project **`psi-monitor` mounts the named volume `psi_data` at
`/app/data`** and holds append-only measurements. Before replacing that
container, take a snapshot the way `lumen-deploy` describes, remembering that the
store is Node's built-in `node:sqlite` rather than better-sqlite3.
`caddy_data` and `caddy_config` are likewise named volumes worth leaving alone.

Check for a volume before assuming a service is disposable:

```bash
docker inspect <service> --format '{{json .Mounts}}'
```

## Not every deploy is a release

Deploying current `main` is normal and complete on its own. There is no version
constant, no manifest, and no release notes to keep in agreement, so there is no
release step to skip and no `release:validate` to run. The commit SHA and the
image digest are the whole record.

This repository has no `BUILD_STATUS.md`. Report the deploy in the response
instead, and state what was not verified as plainly as what was. A deployment
record that only lists successes is not evidence.
