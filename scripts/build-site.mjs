// Assembles the GitHub Pages site in _site/: the product page (site/), the deck viewer and slides (deck/),
// and the screenshots and video both of them use (docs/images/). No build step beyond copying files.
// Run from the repo root: node scripts/build-site.mjs, then serve _site/ with any static server.
import { cp, rm } from 'node:fs/promises';

const out = '_site';
await rm(out, { recursive: true, force: true });
await cp('site', out, { recursive: true });
await cp('deck', `${out}/deck`, { recursive: true });
await cp('docs/images', `${out}/images`, { recursive: true, filter: src => !src.endsWith('.md') });
console.log(`Built ${out}/`);
