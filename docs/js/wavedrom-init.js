window.addEventListener("load", async function () {
  function resolveDocPath(src) {
    if (!src) return src;
    if (/^(https?:)?\/\//.test(src) || src.startsWith("/")) {
      return src;
    }
    if (typeof base_url === "string" && base_url.length > 0 && base_url !== ".") {
      return base_url.replace(/\/$/, "") + "/" + src.replace(/^\.\//, "");
    }
    if (typeof base_url === "string" && base_url === ".") {
      return "./" + src.replace(/^\.\//, "");
    }
    return src;
  }

  const inlineBlocks = document.querySelectorAll(
    "pre > code.language-wavedrom, pre > code.wavedrom"
  );

  inlineBlocks.forEach((code) => {
    const script = document.createElement("script");
    script.type = "WaveDrom";
    script.text = code.textContent;
    const pre = code.parentElement;
    if (pre && pre.parentElement) {
      pre.parentElement.replaceChild(script, pre);
    }
  });

  const fileBlocks = document.querySelectorAll(".wavedrom-file[data-src]");
  await Promise.all(
    Array.from(fileBlocks).map(async (node) => {
      try {
        const src = resolveDocPath(node.dataset.src);
        const response = await fetch(src);
        if (!response.ok) {
          throw new Error("HTTP " + response.status);
        }
        const source = await response.text();
        const script = document.createElement("script");
        script.type = "WaveDrom";
        script.text = source;
        node.replaceWith(script);
      } catch (_err) {
        const pre = document.createElement("pre");
        pre.textContent = "WaveDrom load failed: " + resolveDocPath(node.dataset.src);
        node.replaceWith(pre);
      }
    })
  );

  if (window.WaveDrom && typeof window.WaveDrom.ProcessAll === "function") {
    window.WaveDrom.ProcessAll();
  } else if (window.wavedrom && typeof window.wavedrom.processAll === "function") {
    window.wavedrom.processAll();
  }
});
