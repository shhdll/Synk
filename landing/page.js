// Shared by the plain pages: language switch and the color at the top.
(() => {
  const root = document.documentElement;
  const button = document.getElementById("lang");

  const setLang = (lang) => {
    const ar = lang === "ar";
    root.lang = ar ? "ar" : "en";
    root.dir = ar ? "rtl" : "ltr";
    const other = ar ? "English" : "العربية";
    if (button) {
      button.setAttribute("aria-label", other);
      button.title = other;
    }
    try {
      localStorage.setItem("lang", lang);
    } catch {}
  };

  let saved = null;
  try {
    saved = localStorage.getItem("lang");
  } catch {}
  const asked = new URLSearchParams(location.search).get("lang");
  setLang(asked || saved || (navigator.language.startsWith("ar") ? "ar" : "en"));
  button?.addEventListener("click", () => setLang(root.lang === "ar" ? "en" : "ar"));

  const head = document.querySelector(".head");
  if (head && window.horizonGradient) {
    const HEAD = { light: ["#ffc9a3", "#ffcfe0", "#fff5ef", "#f6f1e6"], dark: ["#7a3f2c", "#5c2c46", "#2a2129", "#17151b"] };
    const mode = () => (window.synkTheme?.isDark() ? "dark" : "light");
    const setColors = horizonGradient(head, {
      colors: HEAD[mode()],
      softness: 1.4,
    });
    window.synkTheme?.onChange(() => setColors?.(HEAD[mode()]));
  }

  // download buttons: same as the home page, the button fills as the file downloads
  const DL_TEXT = {
    en: { done: "Downloaded", started: "Download started" },
    ar: { done: "تم التحميل", started: "بدأ التحميل" },
  };
  const lang = () => (root.lang === "ar" ? "ar" : "en");

  document.querySelectorAll(".dl").forEach((btn) => {
    const label = btn.querySelector(".dl-text > span");
    const text = label.textContent;
    const show = (t) => {
      label.textContent = t;
      label.classList.remove("swap");
      void label.offsetWidth;
      label.classList.add("swap");
    };
    const reset = () => {
      delete btn.dataset.phase;
      btn.style.minWidth = "";
      btn.style.setProperty("--p", 0);
      show(text);
    };
    const finish = (t) => {
      btn.dataset.phase = "done";
      show(t);
      setTimeout(reset, 3000);
    };

    btn.addEventListener("click", async (e) => {
      if (btn.dataset.phase === "loading") {
        e.preventDefault();
        btn.abort?.abort();
        return;
      }
      if (btn.dataset.phase) {
        e.preventDefault();
        return;
      }
      btn.style.minWidth = `${btn.offsetWidth}px`;
      const url = new URL(btn.href, location.href);

      if (url.origin !== location.origin) {
        btn.dataset.phase = "loading";
        setTimeout(() => finish(DL_TEXT[lang()].started), 900);
        return;
      }

      e.preventDefault();
      btn.dataset.phase = "loading";
      show("0%");
      btn.abort = new AbortController();
      const signal = btn.abort.signal;
      // the bar takes at least MIN_MS to fill, so a fast download still shows it
      const MIN_MS = 2000;
      const start = performance.now();
      let real = 0;
      let frame;
      const tick = () => {
        const p = Math.min(real, (performance.now() - start) / MIN_MS);
        btn.style.setProperty("--p", p);
        label.textContent = `${Math.floor(p * 100)}%`;
        if (p < 1) frame = requestAnimationFrame(tick);
      };
      try {
        const res = await fetch(url, { signal });
        if (!res.ok || !res.body) throw new Error("download failed");
        const total = Number(res.headers.get("content-length")) || 0;
        const reader = res.body.getReader();
        const chunks = [];
        let got = 0;
        if (total) tick();
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          chunks.push(value);
          got += value.length;
          if (total) real = got / total;
          else label.textContent = `${Math.round(got / 1048576)} MB`;
        }
        real = 1;
        await new Promise((resolve, reject) => {
          const wait = () => {
            if (signal.aborted) return reject(new DOMException("", "AbortError"));
            if (performance.now() - start >= MIN_MS) return resolve();
            requestAnimationFrame(wait);
          };
          wait();
        });
        cancelAnimationFrame(frame);
        const blob = new Blob(chunks, { type: res.headers.get("content-type") || "application/octet-stream" });
        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = url.pathname.split("/").pop();
        document.body.append(a);
        a.click();
        a.remove();
        setTimeout(() => URL.revokeObjectURL(a.href), 60000);
        btn.style.setProperty("--p", 1);
        finish(DL_TEXT[lang()].done);
      } catch (err) {
        cancelAnimationFrame(frame);
        reset();
        // anything but a cancel: let the browser download it the normal way
        if (err.name !== "AbortError") location.href = url;
      }
    });
  });
})();
