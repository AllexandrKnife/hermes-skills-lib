# Fact-Checking Online Articles — Methodology

Extract and verify claims from web articles on JS-heavy platforms. Covers content extraction from Russian publishing platforms (Dzen, Habr, VC.ru), cross-referencing, and structured credibility assessment.

## When to Use

- User shares a link to a news article or blog post and asks "is this true?"
- Investigating claims in Russian-language publications
- Distinguishing factual reporting from opinion/sensationalism
- Cross-referencing a claim across multiple independent sources

## Extracting Content from JS-Rendered Russian Platforms

Many Russian platforms (Dzen.ru, Habr, VC.ru) are fully client-side rendered. Standard `curl` returns only a shell with SSO/script redirects.

### Dzen.ru — Full Extraction Recipe

```bash
# Step 1: Fetch the page with Googlebot UA (bypasses SSO redirect)
curl -sL \
  -H "User-Agent: Googlebot/2.1 (+http://www.google.com/bot.html)" \
  "https://dzen.ru/a/<ARTICLE_ID>" 2>/dev/null
```

Note: without Googlebot UA, Dzen redirects to `sso.dzen.ru/install` with a login form.

```python
import sys, re, html as htmllib

raw = sys.stdin.read()

# Strip scripts and styles — they contain no article text
cleaned = re.sub(r'<script[^>]*>.*?</script>', '', raw, flags=re.DOTALL)
cleaned = re.sub(r'<style[^>]*>.*?</style>', '', cleaned, flags=re.DOTALL)

# Extract text nodes ≥30 chars (filters out navigation, short labels)
texts = re.findall(r'>([^<]{30,})<', cleaned)

# Also find the article title
title = re.search(r'<title[^>]*>(.*?)</title>', raw)
if title:
    print('TITLE:', title.group(1))

# Output unique text fragments
seen = set()
for t in texts:
    t = htmllib.unescape(t).strip()
    if t and t not in seen:
        seen.add(t)
        print(t)
```

⚠️ **Limitations:**
- Dzen truncates long articles in the initial HTML payload — you may get only the first ~30-50 lines
- Embedded images, videos, and their captions are lost
- Formatting (bold, lists) is stripped

### Habr / VC.ru

Habr and VC.ru are somewhat easier — they include article text in `<meta>` or JSON-LD:

```bash
# JSON-LD often contains the full article
curl -sL -H "User-Agent: Mozilla/5.0" "https://habr.com/ru/articles/<ID>/" \
  | python3 -c "
import sys, re, json
html = sys.stdin.read()
jld = re.search(r'<script[^>]*type=\"application/ld\+json\"[^>]*>(.*?)</script>', html, re.DOTALL)
if jld:
    data = json.loads(jld.group(1))
    print(data.get('articleBody', '')[:5000])
"
```

## Cross-Referencing Claims — Source Hierarchy

Not all sources are equal. When verifying a claim, weight sources in this order:

| Tier | Type | Examples |
|------|------|----------|
| **Primary data** | Raw data, official docs, API responses | ipinfo.io crawl data, official CA/Browser Forum docs, GlobalSign announcements |
| **Reputable press** | Established news outlets with editorial standards | ixbt.com, TJournal, Habr (editorial), Kommersant, TASS |
| **Specialised analysis** | Domain experts, security researchers | Altus Intel, Positive Technologies, Kaspersky |
| **Blogs / opinions** | Individual authors, lifestyle publications | NStor (графика и нейросети), Telegram channels |
| **Anonymous / aggregators** | No named author, no editorial chain | Social media reposts, anonymous Dzen channels |

## Credibility Assessment — 5 Dimensions

### 1. Core Claim Verification

Identify the single factual claim at the heart of the article. Verify it against Tier 1-2 sources.

```python
# Example: check if an event is reported by multiple independent sources
from hermes_tools import terminal

search_queries = [
    "GlobalSign revoke certificates Russia 2026",
    "GlobalSign отзыв сертификатов Россия",
    "CA/Browser Forum sanctions Russia certificates",
]

# Search DuckDuckGo (lite version, no JS)
for q in search_queries:
    result = terminal(f'''
        curl -sL "https://lite.duckduckgo.com/lite/?q={q.replace(' ', '+')}"
        -H "User-Agent: Mozilla/5.0"
    ''')
    # Check if multiple distinct domains appear in results
```

Ask: Is the core event confirmed by 3+ independent sources? If yes, the article's foundation is solid.

### 2. Source Authority

Check the author/publication:

- **What do they normally cover?** A graphics + AI blog writing about SSL certificates is a mismatch — treat as opinion, not reporting
- **Is there a named author?** Anonymous articles require stronger external verification
- **Editorial history:** Does the publication have a track record of corrections or retractions?

### 3. Numerical Accuracy

Cross-reference every hard number:

| What to check | How |
|--------------|-----|
| "5%" (Минцифры) | Is this of all domains, or of domains with certs? Can the denominator change the narrative? |
| "90% market share" | Who said it? Can it be independently verified? Does it refer to a specific subsegment? |
| "15-20K domains affected" | Check against independent crawl data (ipinfo, Netcraft, Shodan) |
| Dates | Do dates in the article match calendar context? (e.g. 2025 vs 2026) |

### 4. Missing Context

What does the article omit that would change the interpretation?

Common omissions:
- **Scope limitation:** "GlobalSign revoked certificates" — but only EV certs, not all certs
- **Alternatives exist but aren't mentioned:** Let's Encrypt covers 74% of .ru sites and is unaffected
- **Existing trend:** Was the decline already happening before the "event"?
- **Regulatory timeline:** Was the rule change announced months ago?

### 5. Tone & Framing

- **Emotional language:** "pозор", "абсурд", "катастрофа" → signals opinion/advocacy, not reporting
- **Binary framing:** "either X or total collapse" — reality is usually more nuanced
- **Villain narrative:** Is there a clear "bad guy" (government, corporation) being set up?

## Structured Report Template

```
## Credibility Assessment: <Article Title>

**Source:** <publication> by <author> | <date>
**URL:** <link>

### Core Claim
<one-sentence summary>

### Verdict: [TRUE / MOSTLY TRUE / MIXED / MOSTLY FALSE / FALSE]
<one-line verdict>

### Evidence

| Dimension | Finding |
|-----------|---------|
| Core claim | [verified / partially verified / unverified] |
| Source authority | [expert publication / reputable / unknown / mismatch] |
| Numbers | [accurate / slightly off / significantly wrong] |
| Missing context | [none / minor / significant omissions] |
| Tone | [neutral / opinion / sensational] |

### Supporting Sources
- [Source 1] — what it says
- [Source 2] — what it says
- [Source 3] — what it says

### Key Gaps / Red Flags
- Bullet list of specific issues found

### Practical Advice (if applicable)
- What the user can actually do about the situation
- Recommended next steps
```

## Example Output (Short Form, Telegram)

For quick responses, use this compressed format:

```
**Достоверность:** 7/10

**Ядро — ПРАВДА.** <confirmed by X, Y, Z>
**Спорное:** <1> <2> <3>

**Что делать:** <practical advice>
```

## Pitfalls

- **Fake news ≠ wrong claim.** An article can be sensationalist and still report a real event. Separate "is the event real?" from "is the article trustworthy?"
- **One source citing another.** A Dzen article citing a Habr article citing a Twitter thread is hearsay, not evidence. Trace to the original primary source.
- **Date in URL ≠ date of event.** Always check the body.
- **Google search results are not sources.** They are pointers. Click through and read.
- **Russian and English coverage of the same event may differ in tone.** Compare both for a balanced view.
- **Don't confuse "5% from total domains" with "5% from domains with SSL certs"** — denominators change everything.

## See Also

- `domain-investigation` — main skill (page content analysis, HTTP profiling, DNS recon)
- Section 3 (Page Content & Branding) in SKILL.md for extracting text from JS sites
