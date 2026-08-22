{
  lib,
  microsoft-edge,
  makeWrapper,
  runCommand,
  symlinkJoin,
  writeText,
}:

let
  manifest = writeText "outlook-cjk-font-fix-manifest.json" (
    builtins.toJSON {
      manifest_version = 3;
      name = "Outlook CJK Font Fix";
      version = "1.0.0";
      description = "Use a sans-serif CJK font for Outlook's Yahei/Simsun fallback stack.";
      content_scripts = [
        {
          matches = [ "https://outlook.cloud.microsoft/*" ];
          js = [ "content.js" ];
          run_at = "document_start";
          all_frames = true;
        }
      ];
    }
  );

  contentScript = writeText "outlook-cjk-font-fix.js" ''
    (() => {
      const replacement = '"Noto Sans CJK SC", "Noto Sans", sans-serif';
      let scheduled = false;

      function visitRules(rules) {
        let changed = 0;
        for (const rule of rules) {
          if (rule.cssRules) changed += visitRules(rule.cssRules);
          if (!rule.style) continue;
          const family = rule.style.getPropertyValue("font-family");
          if (!/Microsoft Yahei UI/i.test(family) || !/Simsun/i.test(family)) continue;
          rule.style.setProperty("font-family", replacement);
          changed += 1;
        }
        return changed;
      }

      function fixFonts() {
        scheduled = false;
        let changed = 0;
        for (const sheet of document.styleSheets) {
          try {
            changed += visitRules(sheet.cssRules);
          } catch (_) {}
        }
        for (const sheet of document.adoptedStyleSheets || []) {
          try {
            changed += visitRules(sheet.cssRules);
          } catch (_) {}
        }
        if (changed) {
          document.documentElement.dataset.outlookCjkFontFix = "active";
        }
      }

      function scheduleFix() {
        if (scheduled) return;
        scheduled = true;
        setTimeout(fixFonts, 0);
      }

      const observer = new MutationObserver(scheduleFix);
      observer.observe(document, { childList: true, subtree: true });
      document.addEventListener("DOMContentLoaded", scheduleFix, { once: true });
      setInterval(fixFonts, 1000);
      scheduleFix();
    })();
  '';

  extension = runCommand "outlook-cjk-font-fix-extension-1.0.0" { } ''
    mkdir -p "$out"
    cp ${manifest} "$out/manifest.json"
    cp ${contentScript} "$out/content.js"
  '';
in
symlinkJoin {
  pname = "microsoft-edge-outlook";
  inherit (microsoft-edge) version;

  paths = [ microsoft-edge ];
  nativeBuildInputs = [ makeWrapper ];

  postBuild = ''
    rm -f "$out/bin/microsoft-edge" "$out/bin/microsoft-edge-stable"
    makeWrapper ${microsoft-edge}/bin/microsoft-edge "$out/bin/microsoft-edge" \
      --add-flags "--load-extension=${extension}"
    ln -s microsoft-edge "$out/bin/microsoft-edge-stable"
  '';

  passthru = {
    inherit extension;
    unwrapped = microsoft-edge;
  };

  meta = microsoft-edge.meta // {
    description = "Microsoft Edge with an Outlook CJK font fallback fix";
    mainProgram = "microsoft-edge";
    platforms = lib.platforms.linux;
  };
}
