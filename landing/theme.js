// Light and dark switch, and the grain on the page background.
// The theme itself is set in each page's head so it doesn't flash.
(() => {
  const root = document.documentElement;
  const button = document.getElementById("theme");
  const listeners = [];
  const isDark = () => root.dataset.theme === "dark";

  const paintGrain = () => {
    const size = 256;
    const c = document.createElement("canvas");
    c.width = c.height = size;
    const g = c.getContext("2d");
    const img = g.createImageData(size, size);
    const base = isDark() ? [0x17, 0x15, 0x1b] : [0xf6, 0xf1, 0xe6];
    for (let i = 0; i < img.data.length; i += 4) {
      const n = (Math.random() - 0.5) * 0.1 * 255;
      img.data[i] = base[0] + n;
      img.data[i + 1] = base[1] + n;
      img.data[i + 2] = base[2] + n;
      img.data[i + 3] = 255;
    }
    g.putImageData(img, 0, 0);
    root.style.background = `${isDark() ? "#17151b" : "#f6f1e6"} url(${c.toDataURL()}) 0 0 / ${size}px ${size}px`;
  };

  const label = () => {
    if (!button) return;
    const text = isDark() ? "Light mode" : "Dark mode";
    button.setAttribute("aria-label", text);
    button.title = text;
  };

  paintGrain();
  label();

  button?.addEventListener("click", () => {
    root.dataset.theme = isDark() ? "light" : "dark";
    try {
      localStorage.setItem("theme", root.dataset.theme);
    } catch {}
    paintGrain();
    label();
    const bar = document.querySelector('meta[name="theme-color"]');
    if (bar) bar.content = isDark() ? "#17151b" : "#f6f1e6";
    listeners.forEach((fn) => fn(isDark()));
  });

  window.synkTheme = { isDark, onChange: (fn) => listeners.push(fn) };
})();
