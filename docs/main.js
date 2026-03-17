(() => {
  // ── Hero parallax: fade + scale + blur as you scroll away ──
  const heroWrap = document.querySelector('.hero-wrap');
  const hero = document.querySelector('.hero');

  // ── Problem section: two lines reveal staggered ──
  const problemWrap = document.querySelector('.scroll-problem');
  const problemLine1 = document.querySelector('.problem-line-1');
  const problemLine2 = document.querySelector('.problem-line-2');

  // ── Step panels ──
  const stepPanels = document.querySelectorAll('.step-panel');

  // ── Statement parallax: kinetic word reveal ──
  const stmtWrap = document.querySelector('.scroll-statement');
  const stmtInner = document.querySelector('.scroll-statement-inner');
  const kineticWords = document.querySelectorAll('.kinetic-word');

  // ── Reveal elements ──
  const reveals = document.querySelectorAll('.reveal');

  // ── Trust badges (scroll-driven) ──
  const trustWrap = document.querySelector('.scroll-trust');
  const trustBadges = document.querySelectorAll('.trust-badge[data-trust]');

  // ── Animation state ──
  let step2Played = false;
  let step3Played = false;

  function clamp(v, min, max) { return Math.min(Math.max(v, min), max); }
  function lerp(a, b, t) { return a + (b - a) * t; }

  // Easing: smooth ease-out
  function easeOutCubic(t) { return 1 - Math.pow(1 - t, 3); }

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

    // ─── Problem: two lines swap quickly, never visible together ───
    if (problemWrap && problemLine1 && problemLine2) {
      const rect = problemWrap.getBoundingClientRect();
      const problemH = problemWrap.offsetHeight;
      const progress = clamp(-rect.top / (problemH - vh), 0, 1);
      
      const label = problemWrap.querySelector('.section-label');
      if (label) {
        const labelP = clamp(progress / 0.15, 0, 1);
        label.style.opacity = labelP;
      }
      
      if (progress < 0.5) {
        const fadeIn = clamp(progress / 0.25, 0, 1);
        const fadeOut = clamp((progress - 0.25) / 0.25, 0, 1);
        const p1 = fadeIn * (1 - fadeOut);
        problemLine1.style.opacity = p1;
        problemLine1.style.transform = `translateY(${lerp(40, 0, fadeIn) + lerp(0, -40, fadeOut)}px)`;
        problemLine1.style.filter = `blur(${lerp(8, 0, fadeIn)}px)`;
        problemLine2.style.opacity = 0;
      } else {
        const p2 = clamp((progress - 0.5) / 0.25, 0, 1);
        problemLine2.style.opacity = p2;
        problemLine2.style.transform = `translateY(${lerp(40, 0, p2)}px)`;
        problemLine2.style.filter = `blur(${lerp(8, 0, p2)}px)`;
        problemLine1.style.opacity = 0;
      }
    }

    // ─── Step panels: activate when centered in viewport ───

    stepPanels.forEach(panel => {
      const rect = panel.getBoundingClientRect();
      const center = rect.top + rect.height / 2;
      const isActive = center > 0 && center < vh;
      panel.classList.toggle('is-active', isActive);

      // Trigger step 1 typing animation once active
      if (isActive && panel.dataset.step === '1') {
        runStep1Animation();
      } else if (!isActive && panel.dataset.step === '1') {
        resetStep1Animation();
      }

      // Trigger step 2 animation once
      if (isActive && panel.dataset.step === '2' && !step2Played) {
        step2Played = true;
        runStep2Animation();
      }

      // Trigger step 3 animation once
      if (isActive && panel.dataset.step === '3' && !step3Played) {
        step3Played = true;
        runStep3Animation();
      }
    });

    // ─── Kinetic statement: word-by-word 3D reveal ───
    if (stmtWrap && kineticWords.length) {
      const rect = stmtWrap.getBoundingClientRect();
      const stmtH = stmtWrap.offsetHeight;
      const progress = clamp(-rect.top / (stmtH - vh), 0, 1);

      // Overall container: subtle scale
      const containerScale = lerp(0.85, 1, clamp(progress * 2, 0, 1));
      stmtInner.style.transform = `scale(${containerScale})`;
      stmtInner.style.perspective = '800px';

      // Each word reveals at a staggered point in the scroll
      const totalWords = kineticWords.length;
      const wordWindow = 0.12; // each word takes 12% of scroll to fully appear

      kineticWords.forEach((word, i) => {
        const wordStart = 0.08 + (i / totalWords) * 0.55;
        const wordProgress = clamp((progress - wordStart) / wordWindow, 0, 1);
        const eased = easeOutCubic(wordProgress);

        const y = lerp(80, 0, eased);
        const rotX = lerp(90, 0, eased);
        const blur = lerp(12, 0, eased);
        const opacity = eased;
        // Slight horizontal scatter that resolves
        const x = lerp((i % 2 === 0 ? -30 : 30), 0, eased);

        word.style.opacity = opacity;
        word.style.transform = `translateY(${y}px) translateX(${x}px) rotateX(${rotX}deg)`;
        word.style.filter = `blur(${blur}px)`;
      });

      // After all words are in, add a subtle glow pulse
      const allIn = progress > 0.75;
      if (allIn) {
        const glowProgress = clamp((progress - 0.75) / 0.25, 0, 1);
        const glowEased = easeOutCubic(glowProgress);
        stmtInner.style.filter = `drop-shadow(0 0 ${lerp(0, 30, glowEased)}px rgba(125, 211, 211, ${lerp(0, 0.3, glowEased)}))`;
      } else {
        stmtInner.style.filter = 'none';
      }
    }

    // ─── Trust badges: scroll-driven staggered reveal ───
    if (trustWrap && trustBadges.length) {
      const rect = trustWrap.getBoundingClientRect();
      const trustH = trustWrap.offsetHeight;
      const progress = clamp(-rect.top / (trustH - vh), 0, 1);

      const totalBadges = trustBadges.length;
      const badgeWindow = 0.22; // each badge takes 22% of scroll to fully appear

      trustBadges.forEach((badge, i) => {
        const badgeStart = 0.1 + (i / totalBadges) * 0.6;
        const badgeProgress = clamp((progress - badgeStart) / badgeWindow, 0, 1);
        const eased = easeOutCubic(badgeProgress);

        const y = lerp(60, 0, eased);
        const scale = lerp(0.85, 1, eased);
        const blur = lerp(8, 0, eased);

        badge.style.opacity = eased;
        badge.style.transform = `translateY(${y}px) scale(${scale})`;
        badge.style.filter = `blur(${blur}px)`;
      });
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

  // ── Step 1 animation: typing effect ──
  let step1Running = false;
  let step1Done = false;
  let step1TimeoutIds = [];

  function runStep1Animation() {
    if (step1Running || step1Done) return;
    step1Running = true;

    const textarea = document.getElementById('step1Textarea');
    const cursor = document.getElementById('step1Cursor');
    const btn = document.getElementById('step1Btn');
    if (!textarea || !cursor || !btn) return;

    const text = "Beginner: Python > all";
    let i = 0;
    textarea.textContent = '';
    cursor.style.display = 'inline-block';
    btn.classList.remove('active');

    function typeChar() {
      if (i < text.length) {
        textarea.textContent += text[i];
        i++;
        // Vary speed for realism: slower on spaces, faster on letters
        const delay = text[i - 1] === ' ' ? 90 + Math.random() * 60 : 35 + Math.random() * 45;
        const tid = setTimeout(typeChar, delay);
        step1TimeoutIds.push(tid);
      } else {
        // Typing done — activate button
        btn.classList.add('active');
        step1Done = true;
        step1Running = false;
      }
    }

    const startTid = setTimeout(typeChar, 400);
    step1TimeoutIds.push(startTid);
  }

  function resetStep1Animation() {
    if (step1Done && !step1Running) return; // keep final state
    // Clear pending timeouts
    step1TimeoutIds.forEach(id => clearTimeout(id));
    step1TimeoutIds = [];
    step1Running = false;

    const textarea = document.getElementById('step1Textarea');
    const cursor = document.getElementById('step1Cursor');
    const btn = document.getElementById('step1Btn');
    if (textarea) textarea.textContent = '';
    if (cursor) cursor.style.display = 'inline-block';
    if (btn) btn.classList.remove('active');
  }

  // ── Step 3 animation: time-based staggered card slide-in ──
  function runStep3Animation() {
    const cards = document.querySelectorAll('#step3Anim .reply-card');
    if (!cards.length) return;

    cards.forEach((card, i) => {
      setTimeout(() => {
        card.classList.add('is-visible');
      }, 400 + i * 500); // stagger: 400ms, 900ms, 1400ms
    });
  }

  // ── Step 2 animation: spinner → tick ──
  function runStep2Animation() {
    const spinner = document.getElementById('step2Spinner');
    const status = document.getElementById('step2Status');
    const result = document.getElementById('step2Result');
    const label = document.querySelector('.sim-label');
    if (!spinner || !status || !result) return;

    // After 2s, swap spinner for green tick
    setTimeout(() => {
      status.style.display = 'none';
      if (label) {
        label.textContent = '3 replies ready';
        label.classList.add('done');
        // Fade label back in with new text
        setTimeout(() => label.classList.remove('done'), 50);
      }
      result.innerHTML =
        '<div class="tick-circle">' +
          '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">' +
            '<polyline points="20 6 9 17 4 12"></polyline>' +
          '</svg>' +
        '</div>' +
        '<span class="sim-done-text">Done — pick your favorite</span>';
      result.classList.add('show');
    }, 2000);
  }

  // Initial call
  onScroll();
})();
