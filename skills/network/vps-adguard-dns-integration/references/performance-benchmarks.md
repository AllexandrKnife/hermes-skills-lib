# Performance Benchmarks — Real-World Results

Tested July 2026 on 3 VPSs. Cold queries = unique domains never seen before (no cache).
Hot queries = repeated domain within TTL.

## Summary Table

| VPS | Provider | Location | Quad9 DoH (cold) | Parallel (cold) | Hot cache | Gain? |
|:---|:---------|:--------:|:----------------:|:---------------:|:---------:|:-----:|
| 46.30.47.120 | EuroDir | Netherlands | 5-11ms | 9-15ms | 0ms | Marginal |
| 87.121.38.60 | Babayka | ? | 9-25ms | 6-8ms | 0ms | Up to 3x |
| 45.134.15.185 | FirstByte | Frankfurt | — | 4-12ms | 0ms | Stable |

## Methodology

```bash
# Before (Quad9 DoH only — old AdGuard config):
for i in 1 2 3; do
  total=0
  for j in $(seq 1 5); do
    d="q$RANDOM$j.com"
    t=$(dig @9.9.9.10 $d +noall +stats 2>&1 | grep 'Query time' | awk '{print $4}')
    [ -n "$t" ] && total=$((total + t))
  done
  echo "batch $i: $((total/5)) ms"
done

# After (AdGuard parallel → unbound + 3 DoH):
for i in 1 2 3; do
  total=0
  for j in $(seq 1 5); do
    d="a$RANDOM$j.com"
    t=$(dig @127.0.0.1 $d +noall +stats 2>&1 | grep 'Query time' | awk '{print $4}')
    [ -n "$t" ] && total=$((total + t))
  done
  echo "batch $i: $((total/5)) ms"
done

# Unbound direct (port 5353, UDP, recursion):
for i in 1 2 3; do
  total=0
  for j in $(seq 1 5); do
    d="u$RANDOM$j.com"
    t=$(dig @127.0.0.1 -p 5353 $d +noall +stats 2>&1 | grep 'Query time' | awk '{print $4}')
    [ -n "$t" ] && total=$((total + t))
  done
  echo "batch $i: $((total/5)) ms"
done
```

## Detailed Results — 46.30.47.120 (EuroDir, Netherlands)

### Before: Quad9 DoH only (load_balance)
```
Common domains (cached):    4-24ms (avg 11ms)
Unique domains (cold):      5-11ms (avg 8ms)
Blocked (local filter):     4-8ms (avg 6ms)
```

### After: unbound + parallel DoH
```
Common domains (cached):    4-16ms (avg 8ms)
Unique domains (cold):      9-15ms (avg 11ms)
Blocked (local filter):     0-4ms (avg 3ms)
Hot cache (repeat query):   0ms
```

**Verdict**: Quad9 anycast nodes are in Amsterdam — essentially same DC as this VPS.
Unbound recursion adds extra hop with no cold-query benefit. The win is **hot cache**
(0ms vs 3ms) and **resilience** (4 upstreams vs 1).

## Detailed Results — 87.121.38.60 (Babayka)

### Before: Quad9 DoH only
```
Unique domains (cold):      9-25ms (avg 18ms)
```

### After: unbound + parallel DoH
```
Unique domains (cold):      6-8ms (avg 7ms)
Hot cache:                  0ms
```

**Verdict**: Significant cold-query improvement. Unbound (UDP) beats Quad9 (TLS) by
eliminating TLS handshake latency. Recommendation: enable unbound here.

## When Unbound Helps vs When It Doesn't

| Scenario | Cold query unbound | Cold query DoH | Winner |
|:---------|:------------------:|:--------------:|:------:|
| VPS near anycast PoP (NL, DE, UK) | 30-150ms (recursion) | 5-15ms (TLS to nearby PoP) | **DoH** |
| VPS far from anycast (RU, Asia, Africa) | 30-150ms (recursion) | 100-400ms (TLS + round-trip) | **Unbound** |
| Hot cache (repeat domains) | <1ms (local RAM) | 3-30ms (anycast) | **Unbound** |
| Failover scenario | Instant (local) | 10s+ (TLS timeout) | **Unbound** |

**Rule of thumb**: Ping your DoH provider. If latency <15ms, unbound won't improve
cold queries — the benefit is hot cache + resilience. If latency >50ms, unbound
will significantly speed up cold queries too.

## Parallel Mode Behaviour

With `upstream_mode: parallel`, AdGuard sends the query to ALL configured
upstreams simultaneously and returns the fastest response. In practice:

- On nearby-anycast VPS: DoH often wins by a hair (~2ms ahead of unbound recursion)
- On far-from-anycast VPS: unbound UDP wins by 10-100ms
- On failure: surviving upstreams keep working with zero delay

Always pair unbound with at least 2 DoH providers in parallel, not as replacement.
