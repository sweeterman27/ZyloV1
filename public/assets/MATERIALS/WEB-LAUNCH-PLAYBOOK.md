# Web Launch Playbook — Astro + Cloudflare

A reusable checklist + field guide distilled from building & launching a real marketing site
(Astro static + Tailwind + TypeScript, hosted on Cloudflare Pages, leads via a Cloudflare Function →
Resend + Google Sheets). Copy this into every new project and work top-to-bottom.

**How to read it:** `☐` = do-it checklist item. **GOTCHA** = a real trap we hit. **WHY** = the reasoning so
you can adapt it. Most "code" items are framework-agnostic ideas even if the snippet is Astro/Cloudflare.

---

## 0. Stack & project conventions

- ☐ **Static-first.** Pre-render everything you can (Astro/Next static export/Eleventy). Static = fast,
  cheap, cacheable, no server to harden. Add server functions only where you truly need them (form POST).
- ☐ **One data source of truth.** Keep product/content data in a single typed file (e.g. `src/data/products.ts`)
  so pages, components, sitemaps, *and your server function* all read the same list. Makes allowlisting trivial.
- ☐ **`public/` for static assets** (images, video, favicons, `_headers`, `robots.txt`).
- ☐ **`.env` for build-time vars only** (see §7). Never commit real secrets.
- ☐ Flag every **placeholder** (price, copy, image) with a `// ⚠️ PLACEHOLDER` comment so you can grep them
  before launch.

---

## 1. Performance — the biggest lever (do this FIRST, not last)

Performance is mostly **images + video + how scripts/CSS load**. Get these right and the Lighthouse score
follows. Order of impact: **media weight → render-blocking resources → caching → third-party scripts.**

### 1a. Images
- ☐ **Use WebP** (or AVIF). Convert with `sharp`.
- ☐ **Size to ~2× display, not to the source.** A logo/icon shown at 80px does **not** need a 1000×1000 file.
  We cut **~1.1 MB** just by resizing oversized images down to sensible dimensions (icons → 160px, grid
  images → ~800px, heroes → ~1600px). **WHY:** "Improve image delivery" is almost always over-sized sources.
- ☐ **Responsive `srcset` + `sizes`** for any image whose displayed size differs a lot between mobile/desktop.
  Mobile gets a small file, desktop gets the big one:
  ```html
  <img src="/img/hero.webp"
       srcset="/img/hero-800.webp 800w, /img/hero.webp 1600w"
       sizes="(max-width: 1023px) 92vw, 1216px"
       width="1600" height="900" alt="…" class="h-auto w-full" />
  ```
- ☐ **Always set `width` + `height`** (or an aspect-ratio container) → prevents layout shift (CLS).
- ☐ **Preload the LCP image** with `fetchpriority="high"`; make sure it's `loading="eager"` (NOT lazy):
  ```html
  <link rel="preload" as="image" href="/img/hero-poster.webp" fetchpriority="high" />
  ```
- ☐ **Lazy-load below-the-fold images** (`loading="lazy"`).
- **GOTCHA — retina vs PageSpeed:** PSI computes "savings" assuming the image should match the *CSS* size
  (e.g. 380px). Phones are 2–3× DPR, so a 380px slot needs ~760 real pixels. **Don't shrink to 1× to chase
  an unscored number — you'll get blurry images on every phone.** ~2× is correct.

### 1b. Hero / background video
- ☐ **Encode sanely:** match the *display* resolution (don't upscale), strip audio if muted, `+faststart`.
  CRF **~23–26** for a full-screen hero (NOT 30 — too soft once upscaled). For a small mobile slot, 720p is plenty.
  ```bash
  ffmpeg -i in.mp4 -c:v libx264 -crf 24 -preset slow -an -movflags +faststart -pix_fmt yuv420p out.mp4
  ```
- ☐ **Lazy-load it** so the (multi-MB) download never blocks first render. Put the source in `data-src`/data-attrs
  and attach it on `window load` + `requestIdleCallback`; show the **poster** meanwhile (poster = your LCP).
- ☐ **Serve a lighter version to phones** (JS picks `data-mobile` vs `data-hd` by viewport). Half the data,
  still sharp on a small screen (it's *downscaled*, not upscaled — no quality loss visible).
- ☐ **Respect `prefers-reduced-motion`, `navigator.connection.saveData`, and 2G** → poster only.
- ☐ For mobile autoplay you MUST have `muted` + `playsinline` + `autoplay` (and call `.play()` after setting src).
- **GOTCHA — keep the ORIGINAL.** Don't delete your master source after compressing. (We deleted a 9 MB
  original and had to recover it from an old Cloudflare deployment alias: `https://<deploy-hash>.pages.dev/...`.)
- **WHY the size is OK after lazy+mobile-split:** the bytes are off the critical path and off phones, so LCP/FCP
  and mobile are unaffected — only the *unscored* desktop "payload" line moves.

### 1c. CSS & JS
- ☐ **Inline small CSS** so it isn't a render-blocking request (Astro: `build: { inlineStylesheets: 'always' }`).
  Removed a ~460 ms render-block this way.
- ☐ **Defer third-party scripts** (analytics, tag managers) — load on first interaction OR ~2 s after load,
  whichever first. Keeps the main thread free during render. *Trade-off: visitors who bounce in <2 s without
  interacting aren't tracked — acceptable for most marketing sites.*
- ☐ **Fonts:** `preconnect` only to origins you actually use, `&display=swap`, and consider self-hosting to kill
  the CSS→woff2 request chain. Remove unused `preconnect` hints (PSI flags them).

### 1d. Caching (`public/_headers` on Cloudflare Pages)
```
/_astro/*            # fingerprinted (hash in filename) → safe forever
  Cache-Control: public, max-age=31536000, immutable
/*.webp
  Cache-Control: public, max-age=2592000   # 30 days
/*.mp4
  Cache-Control: public, max-age=2592000
# HTML: leave it alone → Pages default max-age=0, must-revalidate → instant deploys
```
- ☐ Cloudflare → **Caching → Configuration → Browser Cache TTL → "Respect Existing Headers"** (otherwise a
  fixed TTL overrides your `_headers` and under-caches fingerprinted assets).
- **GOTCHA — stale edge cache on overwrites.** If you overwrite a **same-named, non-fingerprinted** asset
  (e.g. `hero.webp`) and it has a long cache, Cloudflare's edge keeps serving the OLD bytes (`cf-cache-status:
  HIT`). Fix by **(a) using a NEW filename** (e.g. `hero-v2.webp`) — preferred, no purge needed — or
  **(b) Cloudflare → Caching → Purge Everything** after the deploy.

### 1e. Cloudflare speed settings (dashboard, not code)
- ☐ **Rocket Loader → OFF.** It re-executes module scripts via its own runtime → long main-thread tasks and
  weird preload/credentials warnings. Net-negative on an already-bundled site.
- ☐ **Disable Cloudflare Web Analytics if you use GA4** → removes the auto-injected `beacon.min.js` (and its
  PSI cache flag). You can't change that file's headers — it's on Cloudflare's domain.

---

## 2. Analytics

- ☐ **Run exactly ONE analytics path.** We had **GTM *and* a standalone GA4 tag for the same property** →
  GA4 loaded twice → **traffic double-counted** + ~175 KB wasted. Pick one (we kept the direct GA4 tag,
  removed GTM). **Check the network tab for duplicate `gtag/js?id=…` requests.**
- ☐ **Lazy-load it** (see §1c).
- ☐ **GA4 data-stream URL = your live domain.** If you reused a property from a staging/preview domain, just
  edit the web stream's URL — the **Measurement ID stays the same, so no code change.** Don't delete/recreate
  unless you want to dump old data.
- ☐ **Web stream only.** iOS/Android streams are for *native apps*; a website (even on phones) is web traffic.

---

## 3. SEO

- ☐ Set `site:` in `astro.config` → drives canonical URLs, OG, sitemap, robots.
- ☐ Ship **`sitemap-index.xml`** (Astro sitemap integration) + **`robots.txt`** pointing at it.
- ☐ Per-page **`<title>`, meta description, canonical, Open Graph/Twitter, JSON-LD** (Organization site-wide;
  Product/BlogPosting/Breadcrumb per page).
- ☐ **Google Search Console:** add a **Domain** property (covers apex+www+http/https) → verify with a **DNS TXT**
  record in Cloudflare → **Sitemaps → submit `sitemap-index.xml`** → optionally **URL Inspection → Request
  indexing** for the homepage + key pages.
- ☐ **Link GSC ↔ GA4** (GA4 Admin → Product links → Search Console links). A GA4 web stream links to only ONE
  GSC property — unlink the old one first.
- **Expectation-setting:** a brand-new property indexes slowly (1 page → full site over days/weeks). "1 indexed"
  on day one is **normal**, not a bug. "Page with redirect" = redirecting URL variants (trailing-slash, old
  domain) — expected, Google indexes the destination.

---

## 4. Forms & lead capture — security (server is the boss)

The browser is bypassable; **validate on the server.** Layer the defenses (each is cheap):

**Server function (`/api/lead`), in order:**
1. ☐ **Same-origin check** (block cross-site POSTs).
2. ☐ **Payload size cap** (e.g. 16 KB).
3. ☐ **Honeypot** field — if filled, pretend success (don't tip off bots).
4. ☐ **Source allowlist** (only your own forms' `source` values).
5. ☐ **Email regex + length cap**; **required-field** check per source.
6. ☐ **Length-REJECT pass** (not just truncate) so oversized inputs are rejected before heuristics run.
7. ☐ **Format validation** — e.g. phone normalized to digits then matched to a real shape (PH: `09XXXXXXXXX`
   / `+639XXXXXXXXX` / landline). A bare "required" check passes `"-"`.
8. ☐ **Allowlist trusted-display fields** — resolve `product` against your catalog and **overwrite** the
   client-supplied name; allowlist `payment`; coerce `quantity` to a bounded int. Don't email attacker-chosen
   strings (esp. for a confirmation email sent FROM your domain TO an attacker-chosen address).
9. ☐ **Spam heuristics** (reject links in name/phone, cap total links).
10. ☐ **Cloudflare Turnstile** (only enforced when the secret is set — see §5).
11. ☐ **CSV / formula injection** — before writing to Google Sheets, prefix any value starting with `= + - @
    TAB CR` with a `'` so it can't execute as a Sheet formula when the team opens it.
12. ☐ **`escHtml()` every user value** placed into HTML emails (include the single quote in the escape map).

**Client (UX mirror of the server, never the only line):**
- ☐ `maxlength` on every field (match server caps); `type`/`inputmode`/`pattern` for email & phone; live-strip
  non-numeric from phone; lowercase/trim email on submit.

**Rate limiting (dashboard):**
- ☐ Cloudflare → the **domain** → **Security → WAF → Rate limiting rules** → match `URI Path eq /api/lead` →
  **Block** (e.g. 10 req / 10 s per IP). **WHY:** without it, a form endpoint that sends branded email is an
  open relay (attacker triggers mail to arbitrary addresses from your domain).
- ☐ **Test end-to-end:** submit a real lead and confirm BOTH a Google Sheet row **and** the email arrive.

---

## 5. Cloudflare Turnstile (bot protection)

- ☐ **Site key** is public → goes in `.env` as `PUBLIC_TURNSTILE_SITE_KEY` (baked at build, since direct-upload
  builds locally). **Secret key** is server-side → Cloudflare **Pages → Settings → Variables (runtime,
  encrypted)** as `TURNSTILE_SECRET_KEY`.
- ☐ **`turnstileOk()` fails OPEN** when the secret is unset (renders but enforces nothing). After any domain/host
  migration, **re-confirm the secret is set in Production (and Preview if you test there).**
- ☐ **Load the Turnstile script ONLY on pages with a form** (gate it via a Layout prop), not site-wide — it's
  ~400 KB. We moved it off the homepage and saved that on every form-less page.
- ☐ **If you remove the widget from a low-value form** (e.g. a newsletter popup), **also exempt that `source`
  server-side** from the Turnstile check — otherwise those submissions silently 403.

---

## 6. Email (transactional)

- ☐ **Inbound:** Cloudflare **Email Routing** (forward `help@`/`sales@` → a real inbox). Auto-adds MX + SPF + DKIM.
- ☐ **Outbound:** **Resend** (or similar). Verify your domain; put the SPF/DKIM on a **subdomain** (e.g.
  `send.yourdomain.com`) so it doesn't clash with Email Routing's root SPF (only one SPF record per name).
- ☐ Pick the **closest region** to your users.
- ☐ **API key lives in the server runtime env only** — never in client/HTML.

---

## 7. Deployment — Cloudflare Pages (direct upload, no Git needed)

- ☐ Build then deploy: `npx wrangler pages deploy dist --project-name=<proj> --branch=production`.
  Functions in `functions/` auto-bundle; `public/_headers` is picked up automatically.
- ☐ **Env vars:** `PUBLIC_*` are **build-time** (must be in local `.env` before `npm run build`). Server secrets
  go in **Pages runtime** (Settings → Variables, encrypted): `RESEND_API_KEY`, `TURNSTILE_SECRET_KEY`,
  `SHEET_SECRET`, etc.
- ☐ **Custom domains:** add apex + `www` (CNAME flattening → both proxied/orange, auto-SSL).
- ☐ **Verify the Functions bundle before you trust a deploy** — especially if a Function imports TS from outside
  `functions/` (e.g. `../../src/data/products`). Sanity-check with esbuild first:
  ```bash
  npx esbuild functions/api/lead.js --bundle --format=esm --platform=neutral --outfile=/tmp/_check.js
  ```
- **GOTCHA:** old deployment aliases (`https://<hash>.<proj>.pages.dev`) stay live and immutable — handy for
  **recovering a file you deleted from the current build.**

---

## 8. Domain migration & redirects

- ☐ **Old domain → new domain:** Cloudflare → old domain → **Rules → Redirect Rules → Create** → "Redirect to a
  different domain" template → **All incoming requests** → Dynamic: `concat("https://NEWDOMAIN",
  http.request.uri.path)` → **301** → preserve query. Covers apex + www, http + https, all paths.
- ☐ Verify with `curl -sI` (look for `301` + correct `Location`), then follow the chain to a `200`.
- **GOTCHA — orange-to-orange (O2O).** If the old domain's origin is **also on Cloudflare** (Shopify, another
  CF site, etc.), your zone hands the request straight to that origin **before your Redirect Rule runs** — so the
  redirect silently doesn't fire (you keep seeing the old site, `cf-cache-status: HIT`, `powered-by: Shopify`).
  **Fix:** point the apex DNS record at a **dummy proxied IP** (`192.0.2.1`, orange cloud) so there's no
  CF-origin to hand off to → your rule fires (the dummy IP is never reached). Allow ~1–2 min edge propagation.

---

## 9. Accessibility (WCAG 2.1 AA)

- ☐ **Contrast:** ≥ **4.5:1** for normal text, ≥ **3:1** for large text (≥24px, or ≥18.66px **bold**).
  - **GOTCHA:** **opacity-dimmed** text fails — a scroll-spy that fades inactive items to `opacity:0.3` drops
    real contrast below the bar. Keep dimmed text ≥ ~0.7 opacity, or use a darker solid color.
  - **GOTCHA:** `text-lg` (18px) bold is **below** the large-text threshold → needs 4.5:1, not 3:1.
  - Brand accents on white often fail — darken them (e.g. our gold `#b0873f` → `#856421`; blue `brand-600` →
    `brand-700`) for small text.
- ☐ **Semantic markup:** valid `<dl>` (only `<dt>`/`<dd>` groups — don't nest images + divs inside), one `<h1>`,
  logical headings, `alt` on meaningful images (`alt=""` on decorative).
- ☐ **Touch targets ≥ 24×24px with spacing.** Targets whose 24px hit-areas **overlap** fail (we had two image
  hotspots ~21px apart — repositioned them ~39px apart). Bigger isn't always the fix — **spacing** is.
- ☐ **Explicit image `width`/`height`** (also a CLS fix).

---

## 10. Reading PageSpeed/Lighthouse without losing your mind

- ☐ **Know scored vs unscored.** Items tagged **`Unscored`** (most "Insights"/"Diagnostics": network dependency
  tree, "use efficient cache lifetimes" for third-parties, image-dimension hints) **don't change your score.**
  Fix them only if they're cheap or genuinely improve UX.
- ☐ **Third-party items are often unfixable** — Cloudflare's `beacon.min.js`, GA4's `gtag.js` (the "unused JS").
  You can't shrink someone else's file; you can only remove the feature.
- ☐ **PSI ignores device pixel ratio** → it always wants 1× images. **Don't blur for an unscored saving.**
- ☐ **PSI never shows literal zero.** Even great sites carry a few diagnostics. Optimize the **scored** metrics
  (LCP, CLS, TBT/INP, FCP) and the obvious wins; then **stop** — chasing fractions means removing features you
  want.

---

## 11. Lessons learned / gotchas (the highlight reel)

- **Server-side validation is authoritative** — the client is a UX mirror, nothing more.
- **One analytics tag** — duplicate GA4 (direct + via GTM) double-counts traffic.
- **Keep asset originals** — don't delete masters after compressing.
- **New filename for any changed non-fingerprinted asset** — sidesteps the stale edge cache (no purge needed).
- **Verify the Functions bundle** before trusting a deploy (cross-boundary TS imports can break it).
- **Don't over-compress hero video** — match resolution to display; CRF 30 + upscale = soft.
- **Turnstile fails open** when the secret is missing; and gate its script to form pages only.
- **Orange-to-orange** silently bypasses redirect rules when the origin is also on Cloudflare.
- **Cloudflare Browser Cache TTL** can silently override your `_headers` — set it to "Respect Existing Headers".
- **Don't let PageSpeed talk you into 1× images** or into deleting features for unscored points.

---

## 12. Condensed pre-launch checklist (copy-paste per project)

```
PERF
 ☐ Images WebP, sized ~2× display, srcset+sizes, width/height set
 ☐ LCP image preloaded (fetchpriority=high), not lazy
 ☐ Hero video: compressed, lazy-loaded, lighter mobile variant, poster preloaded, original kept
 ☐ CSS inlined; third-party scripts deferred; fonts swap + preconnect (used origins only)
 ☐ _headers: /_astro immutable 1yr, media 30d, HTML untouched
 ☐ Cloudflare: Browser Cache TTL = Respect Headers; Rocket Loader OFF
ANALYTICS / SEO
 ☐ ONE analytics tag, lazy-loaded; GA4 stream URL = live domain
 ☐ sitemap + robots + canonical + OG + JSON-LD
 ☐ GSC domain property verified (DNS TXT) + sitemap submitted + linked to GA4
FORMS / SECURITY
 ☐ Server: same-origin, size cap, honeypot, source+field validation, length-reject,
    format checks, product/payment allowlist, qty coerce, CSV-injection guard, escHtml
 ☐ Turnstile: site key in .env, secret in Pages runtime, script gated to form pages
 ☐ Rate-limit rule on the form endpoint
 ☐ End-to-end test: Sheet row + email both arrive
EMAIL / DEPLOY / DOMAIN
 ☐ Inbound (Email Routing) + outbound (Resend, SPF/DKIM on subdomain) working
 ☐ Secrets in runtime env only; PUBLIC_* baked at build
 ☐ Functions bundle verified; custom domains (apex+www) proxied + SSL
 ☐ Old domain → 301 Redirect Rule (mind orange-to-orange → dummy IP)
A11Y
 ☐ Contrast AA (watch opacity-dimmed text + brand accents on white)
 ☐ Valid semantic markup; touch targets ≥24px + spaced; image dimensions set
LAUNCH
 ☐ Placeholders (prices/copy) confirmed; purge cache if you overwrote same-named assets
```

---
*Generated from the Zleep AI build — adapt freely. The principles travel; the exact Cloudflare/Astro steps
are just the current implementation.*
