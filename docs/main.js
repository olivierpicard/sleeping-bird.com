(() => {
  // ── Hero parallax: fade + scale + blur as you scroll away ──
  const heroWrap = document.querySelector('.hero-wrap');
  const hero = document.querySelector('.hero');

  // ── Statement parallax: scale up + de-blur as you scroll into it ──
  const stmtWrap = document.querySelector('.scroll-statement');
  const stmtInner = document.querySelector('.scroll-statement-inner');

  // ── Reveal elements ──
  const reveals = document.querySelectorAll('.reveal');

  function clamp(v, min, max) { return Math.min(Math.max(v, min), max); }
  function lerp(a, b, t) { return a + (b - a) * t; }

  function onScroll() {
    const scrollY = window.scrollY;
    const vh = window.innerHeight;

    // ─── Hero: fade out, scale down, blur ───
    if (heroWrap) {
      const heroH = heroWrap.offsetHeight;
      const progress = clamp(scrollY / (heroH - vh), 0, 1);
      const opacity = 1 - progress;
      const scale = lerp(1, 0.92, progress);
      const blur = lerp(0, 12, progress);
      hero.style.opacity = opacity;
      hero.style.transform = `scale(${scale})`;
      hero.style.filter = `blur(${blur}px)`;
    }

    // ─── Statement: scale up from small, de-blur ───
    if (stmtWrap && stmtInner) {
      const rect = stmtWrap.getBoundingClientRect();
      const stmtH = stmtWrap.offsetHeight;
      // progress 0 = just entering viewport, 1 = fully scrolled through
      const progress = clamp(-rect.top / (stmtH - vh), 0, 1);
      const scale = lerp(0.7, 1, progress);
      const blur = lerp(10, 0, progress);
      const opacity = lerp(0, 1, clamp(progress * 2, 0, 1)); // fade in first half
      stmtInner.style.transform = `scale(${scale})`;
      stmtInner.style.filter = `blur(${blur}px)`;
      stmtInner.style.opacity = opacity;
    }

    // ─── Reveal elements when they enter viewport ───
    reveals.forEach(el => {
      if (el.classList.contains('is-visible')) return;
      const rect = el.getBoundingClientRect();
      if (rect.top < vh * 0.85) {
        el.classList.add('is-visible');
      }
    });
  }

  // Use requestAnimationFrame for smooth 60fps scroll
  let ticking = false;
  window.addEventListener('scroll', () => {
    if (!ticking) {
      requestAnimationFrame(() => { onScroll(); ticking = false; });
      ticking = true;
    }
  }, { passive: true });

  // Initial call
  onScroll();
})();
