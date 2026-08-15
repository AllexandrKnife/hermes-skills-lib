# Social Media Content Extraction via OpenGraph Tags

Passive extraction of post content from social media platforms without authentication. Platforms embed metadata in OpenGraph (`og:`) and Twitter Card (`twitter:`) meta tags for link previews. These are present in the initial HTML and don't require JavaScript rendering.

## Instagram

Fetch the post URL and parse `<meta property="og:*">` tags. Instagram returns author, date, likes count, full caption, and image URL.

```bash
curl -s "https://www.instagram.com/p/SHORTCODE/" | python3 -c '
import sys, re, html as html_mod
raw = sys.stdin.read()
for prop in ["og:title", "og:description", "og:image", "og:url", "twitter:title", "twitter:image"]:
    m = re.search(r"<meta (?:property|name)=\"" + prop + r"\" content=\"([^\"]+)\"", raw)
    if m:
        val = html_mod.unescape(m.group(1))
        print(f"{prop}: {val}")
'
```

**What you get:**
- Author (`og:title` / `twitter:title`)
- Post date and full caption (`og:description` — includes likes, comments, text, hashtags)
- Image URL (`og:image` — HEIC format; append `?stp=dst-jpg_e35` for JPEG)
- Post ID (`al:ios:url` → `instagram://media?id=...`)

**Limitations:** No comments (only count), video thumbnails only, private posts blocked.

## Twitter/X

Twitter/X requires JS to render. Use the oEmbed endpoint (no auth):

```bash
curl -s "https://publish.twitter.com/oembed?url=https://twitter.com/USER/status/ID" | python3 -c '
import sys, json, html
d = json.load(sys.stdin)
print("Author:", d.get("author_name"))
print("HTML preview:", html.unescape(d.get("html", "")[:500]))
'
```

Or use the `xurl` skill for proper API access.

## YouTube

```bash
curl -s "https://www.youtube.com/watch?v=VIDEO_ID" | python3 -c '
import sys, re, html as html_mod
raw = sys.stdin.read()
for prefix in ["og:", "twitter:"]:
    for tag in re.findall(r"<meta (?:property|name)=\"" + prefix + r"([^\"]+)\" content=\"([^\"]+)\"", raw):
        print(f"{prefix}{tag[0]}: {html_mod.unescape(tag[1])}")
'
```

**Returns:** title, description, image, channel, duration, video URL.

## Generic Shell Function

```bash
og_extract() {
    curl -sL --max-time 15 "$1" | python3 -c "
import sys, re, html
raw = sys.stdin.read()
for prop in ['og:title','og:description','og:image','og:site_name','og:url','twitter:card','twitter:title']:
    m = re.search(r'<meta (?:property|name)=\"' + prop + r'\" content=\"([^\"]+)\"', raw)
    if m: print(prop + ': ' + html.unescape(m.group(1)))
"
}
og_extract "https://www.instagram.com/p/SHORTCODE/"
og_extract "https://www.youtube.com/watch?v=VIDEO_ID"
```

## Pitfalls

- **HTML entities** — decoded with `html.unescape()`. Always unescape extracted values.
- **HEIC images** — Instagram serves `.heic` for modern posts. Use `?stp=dst-jpg_e35` suffix for JPEG fallback.
- **Crawler limits** — platforms may rate-limit or serve different content to bots. Rotate User-Agent if needed.
- **No auth = partial data** — always less than a logged-in view. No comments, no follower data, no stories.
