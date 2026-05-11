# Clarity Website

Static support and privacy pages for the App Store listing.

## Local Preview

```sh
python3 -m http.server 4173 --directory Clarity/site
```

Then open:

- `http://127.0.0.1:4173/support/`
- `http://127.0.0.1:4173/privacy/`

## Vercel Deployment

Production deployment:

- Home: `https://site-iota-three-94.vercel.app`
- Support: `https://site-iota-three-94.vercel.app/support`
- Privacy Policy: `https://site-iota-three-94.vercel.app/privacy`

Import the repository into Vercel and set the project root directory to:

```text
Clarity/site
```

There is no build command and no output directory. After deployment, use:

- Support URL: `https://YOUR-VERCEL-DOMAIN/support`
- Privacy Policy URL: `https://YOUR-VERCEL-DOMAIN/privacy`
