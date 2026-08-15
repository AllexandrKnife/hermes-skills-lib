---
name: academic-profiling
category: research
description: "Use when Profile academic researchers and their"
critic_status: done
version: 1.0.1
author: Hermes Agent
tags: [osint, research, biographical, academic, contacts, profiling]
triggers:
  - user asks to find "who else" works on a topic
  - user asks to profile a Russian academic (publication list, RSCI/eLibrary, naucometric analysis)
  - user asks who is alive/dead among a group of researchers
  - user needs contact info (email, phone, address) for academics
  - building a research lineage tree (who studied with/under whom)
  - mapping out an academic department's current team
---
## When to Use

Use when Profile academic researchers and their.


# Academic Profiling

Workflow for researching academic researchers and their networks.

## Related Reference Files

- `references/uva-dops-contacts.md` — current UVA Division of Perceptual Studies staff directory with emails/phones (verified 2026-07-02)
- `references/stevenson-lineage.md` — Ian Stevenson's full research lineage: living/deceased statuses, successors, collaborators, contact info
- `references/russian-academic-sources.md` — российские учёные: обход eLibrary/РИНЦ, КиберЛенинка, 1economic (lib ID = хвост DOI, токены+Referer), rppe OJS, eehacrt, страницы вузов (КГАСУ/КФУ), находка публикаций через списки литературы, фильтрация однофамильцев, PDF→txt (pymupdf, shutil.move)
- `templates/naucometric-profile-prompt.txt` — промпт наукометрического анализа: темы → скилы → качество → направления исследований (с механикой дайджеста и самопроверки подсчётов)

## Phase 1: Trace the Lineage

Start with the known researcher and find their intellectual descendants / collaborators.

### Sources (in order of reliability)

1. **Wikipedia article** — lead section and "See also" often list collaborators and successors. Search for phrases like "continued by", "with", "collaborated with", "took over from".
   - Check the article's first paragraph for named collaborators
   - Scroll to the "See also" section for linked researchers
   - Look in "Personal life" / "Death" sections for successors

2. **Department/Division website** — academic units list current faculty. Key search:
   - University site → "[Department] faculty and staff" or "[Division] people"
   - Look for specific named successors and their sub-specialties
   - URL patterns often: `/department/people/`, `/division/staff/`, `/dops-staff/`

3. **Google Scholar / PubMed** — see who cites the researcher and continues their work
   - Search: `"[researcher name] reincarnation"` or `"[researcher name] past-life"`
   - Look for co-authors who publish regularly on the same topics

4. **News articles / obituaries** — obituaries list collaborators and who continues the work
   - NYT obituaries are detailed (e.g. Stevenson's obit listed Tucker as successor)
   - Academic obituaries (BMJ, Lancet) mention who took over

### Key query patterns for Wikipedia

Use browser to open the Wikipedia page, then extract the full text:

```
browser_navigate(url="https://en.wikipedia.org/wiki/SOMEONE")
browser_console(expression="document.querySelector('.mw-parser-output').innerText")
```

Search for text patterns: "continued", "took over", "collaborator", "colleague", "successor", "with", "co-authored".

## Phase 2: Check Status (Alive / Deceased)

### Wikipedia check
- **Present tense** ("is a professor", "is a researcher") = alive
- **Past tense** ("was the head", "was a professor") = possibly deceased or retired; check further
- **Death date** listed in infobox or "Died" line = deceased
- **Birth year** — if born before 1940 and no recent publication activity, likely retired or deceased

### Quick checks
- Wikipedia infobox shows "Died: DATE" for deceased
- Wikipedia categories: check if page has "YYYY births" and no "YYYY deaths"
- University faculty page — "Professor Emeritus" means retired, usually still alive
- Recent publication on PubMed/Google Scholar (last 3 years) = alive and active

## Phase 3: Extract Contact Information

### University staff pages
URL pattern discovery (academic sites vary):

```
# Try these patterns in order:
med.virginia.edu/perceptual-studies/dops-staff/[name]/
med.virginia.edu/perceptual-studies/people/[name]/
[university].edu/[department]/faculty/[name]/
[university].edu/[department]/dops-staff/[name]/
```

### What to extract
- **Email** — usually obfuscated on page, extract from HTML or JavaScript
- **Phone** — office phone number
- **Address** — mailing address (P.O. Box)
- **Role** — Professor, Research Assistant, etc.
- **Research interests** — to confirm relevance
- **Education** — PhD year, institution

### When no individual email is available
Use the department's general contact with a specific "Attn: Name" note.

Common DOPS email patterns at UVA:
- General: dops@virginia.edu
- Individual format: [initials]@uvahealth.org (e.g. mp8ce, zzs2jq, jkp2n)
- Phone: 434-924-2281 (DOPS main line)

## Phase 4: Build the Directory

Structure the output as:

```
**Category labels:**

1. **Name, Title** — role, institution
   - Status: alive/deceased
   - Specialization: short list
   - Contact: email / phone / mail / "via department"
   - Note: relevant details

2. ...
```

Separate sections for:
- Direct successors (continued the same research line)
- Collaborators (worked together, parallel research)
- Current team (active at the institution today)
- Deceased (with death year)

## Tools and Techniques

### For university sites that load slowly or 404
If the modern CMS version of a page 404s, try:
- Older URL formats (WordPress slug-based)
- curl with longer timeout: `curl -sL --max-time 30 URL`
- Extract staff list from the main page rather than individual pages
- Use the "Faculty and Staff" listing page (one curl call gets everyone)

### Scraping structured data from staff pages
```
# Extract text from HTML by stripping tags
curl -sL URL | python3 -c "
import sys, re, html
content = sys.stdin.read()
text = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.DOTALL)
text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL)
text = re.sub(r'<[^>]+>', '\n', text)
text = html.unescape(text)
lines = [l.strip() for l in text.split('\n') if l.strip()]
for l in lines:
    print(l)
"
```

### For Wikipedia pages that load slowly
If browser times out on Wikipedia, try:
- English Wikipedia is usually fast; use the browser
- Russian Wikipedia may be slower — use curl on ru.wikipedia.org
- Extract via JS console: `document.querySelector('.mw-parser-output').innerText`

## Pitfalls

- **Wikipedia doesn't always list death dates prominently.** Always check the infobox (right sidebar) and the first paragraph. If a researcher has a Wikipedia page with no "Died" field, they're presumed alive (but verify with other sources).
- **Past tense in a Wikipedia article != deceased.** "Was the head of department" means they're no longer in that role (retired), not that they died. Look for explicit "Died" or death year.
- **University CMS pages change.** Staff pages 404, move, or get restructured. Be ready to try 2-3 URL variants.
- **Bot detection on academic sites.** Some university sites behind Cloudflare/WAF may block headless browser. Try curl first.
- **"Research Assistant" may not have a public email.** Junior staff often don't get individual pages. Route through the department's general contact.
- **Email obfuscation:** Modern academic sites often hide emails behind JavaScript. If curl returns HTML without emails, use the browser (it runs JS).
- **Professor Emeritus = retired, not dead.** Don't list them as deceased unless there's a death notice.
- **Infinite redirects or CAPTCHAs on some .edu sites.** Use curl with `-L` and `--max-time` to avoid hanging. If a CAPTCHA appears, try the Wayback Machine or use the browser tools.
