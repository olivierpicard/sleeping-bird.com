I want to make a whole new landing page.
Title: Sleeping Bird
Slogan: Faster And better replies on X (You can adjust a bit)\
Link to chrome store: https://chrome.google.com/webstore/detail/jmafaeednncmehcojgbehpoklohbmikc\
Link to github: https://github.com/olivierpicard/sleeping-bird.com\


Chrome store description: Draft a quick reply idea on X.com and let Sleeping Bird expand it into 3 polished variations you can copy with one click

You know what you want to say. You just don't always have the time (or energy) to say it well.

Sleeping Bird doesn't write replies for you. It takes your rough idea — a few words, a half-formed thought — and turns it into 3 polished variations that keep your voice, your opinion, and your intent intact. You pick the one that fits, copy it, and post.

No ghostwriting. No generic AI slop. Just your ideas, sharpened.

How it works:

You're on X, about to reply to a tweet. Click the ✨ icon in the compose toolbar.
Type your draft — even a messy one-liner is fine.
Sleeping Bird gives you 3 variations. Click the one you like, it's copied to your clipboard. Done.
Why people use it: • You reply a lot and want to move faster without sounding rushed • English isn't your first language and you want your replies to land right • You have the ideas but struggle to phrase them clearly • You want to grow on X by engaging more, without sacrificing quality

What it's not: • It's not a bot. It doesn't post for you. • It's not generating opinions. The ideas are yours. • It's not collecting your data. Everything runs client-side with your own Grok API key. No servers, no tracking, nothing leaves your browser.

Privacy first: Your API key is stored locally in your browser. Sleeping Bird has zero backend — no analytics, no accounts, no data collection. Period.

Requires a Grok API key from console.x.ai (free tier available).

Constraint: Don't accentuate on the AI response or AI mechanism, accentuate on "its your own voice, your own idea but on steroid", accentuate also on the fact that you can replies fast

The main color are black and white. Take exemple on https://x.ai website theme 


















Implementation Plan — Sleeping Bird Landing Page Redesign

Problem Statement:
Replace the current light-themed, minimal landing page with a fully dark, x.ai-
inspired landing page that emphasizes speed and "your voice, your ideas — on 
steroids" rather than AI mechanics.

Requirements:
- Fully dark theme (black background, white text) inspired by x.ai
- Inter font from Google Fonts
- Subtle scroll fade-in animations + hover effects (JS + CSS)
- Sections: Hero, How It Works, Why People Use It, What It's Not, Footer
- Primary CTA → Chrome Web Store, secondary → GitHub
- Messaging constraint: don't accentuate AI — accentuate speed and "your voice 
amplified"
- Separate CSS and JS files
- Privacy page should also be updated to match the new dark theme
- Hosted via GitHub Pages from docs/ folder (existing CNAME: sleeping-bird.com)

Proposed Solution:
A single-page static site with 3 files (index.html, style.css, main.js) in the 
docs/ directory. Dark background (#000 or near-black), white/light gray text, 
clean sections with generous spacing. JS handles intersection observer-based 
fade-in animations. The privacy page gets a matching dark restyle.

Task Breakdown:

Task 1: Create the base HTML structure and CSS file with dark theme
- Objective: Set up docs/style.css with the dark theme foundation (colors, 
typography, layout resets) and rewrite docs/index.html to link to the external 
CSS and Google Fonts (Inter). Build the hero section with title "Sleeping Bird",
slogan, and two CTA buttons (Chrome Store primary, GitHub secondary).
- Implementation: Create docs/style.css with CSS variables for the color palette
(black bg, white text, subtle grays for secondary text, accent for hover states
). Set up responsive container, Inter font import. Rewrite docs/index.html with 
semantic HTML, linking to the new CSS.
- Demo: Opening docs/index.html in a browser shows a dark page with the hero 
section — title, slogan, two buttons — styled cleanly in the x.ai aesthetic.

Task 2: Add the "How It Works" section
- Objective: Build the 3-step flow section below the hero.
- Implementation: Three numbered steps with concise copy: (1) Click ✨ in the 
compose toolbar, (2) Type your rough idea, (3) Pick a variation, copy, post. 
Styled as a horizontal row on desktop, stacked on mobile. Step numbers styled as
circular badges.
- Demo: Scrolling past the hero reveals a clean "How it works" section with 3 
steps, responsive layout.

Task 3: Add the "Why People Use It" section
- Objective: Build the 4 use-case cards section.
- Implementation: Four cards/items with the messaging: reply faster, English isn
't your first language, have ideas but struggle
