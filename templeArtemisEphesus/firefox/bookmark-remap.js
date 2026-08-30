// bookmark-remap.js -- Firefox autoconfig script (appended to mozilla.cfg /
// "autoconfig.cfg" via the nixpkgs firefox wrapper's `extraPrefsFiles`
// override attribute).
//
// Purpose: remap the "Bookmark This Page" keybinding
//     Ctrl+D  ->  Ctrl+B
// Ctrl+B is freed up first by unbinding the bookmarks-sidebar toggle, so the
// new mapping is unambiguous.
//
// NOTE: the first line of an autoconfig script MUST be a comment.
//
// This script runs at startup, chrome-privileged, before any browser window
// exists. Key elements live in chrome://browser/content/browser.xhtml and
// their literal key character comes from Fluent localization
// (bookmark-this-page-shortcut .key = D), so the data-l10n-id attribute has to
// be dropped when overriding, otherwise Fluent would restore "D" later.

(function () {
  "use strict";

  const { classes: Cc, interfaces: Ci } = Components;
  const observerService = Cc["@mozilla.org/observer-service;1"]
    .getService(Ci.nsIObserverService);
  const windowWatcher = Cc["@mozilla.org/embedcomp/window-watcher;1"]
    .getService(Ci.nsIWindowWatcher);

  // --- test hook -----------------------------------------------------------
  // When the environment variable KBS_TEST_OUT is set, append a status record
  // to that file. Used by the automated test of this nix package only.
  let testSink = null;
  try {
    const env = Cc["@mozilla.org/process/environment;1"]
      .getService(Ci.nsIEnvironment);
    const out = env.get("KBS_TEST_OUT");
    if (out) {
      testSink = function (line) {
        try {
          const file = Cc["@mozilla.org/file/local;1"].createInstance(Ci.nsIFile);
          file.initWithPath(out);
          const foStream = Cc["@mozilla.org/network/file-output-stream;1"]
            .createInstance(Ci.nsIFileOutputStream);
          // PR_WRONLY | PR_APPEND | PR_CREATE_FILE
          foStream.init(file, 0x02 | 0x08 | 0x10, 0o644, 0);
          foStream.write(line, line.length);
          foStream.close();
        } catch (e) { /* ignore */ }
      };
      testSink("autoconfig-loaded\n");
    }
  } catch (e) { /* not a test run */ }
  // -------------------------------------------------------------------------

  function remapWindow(aWindow) {
    if (!aWindow || !aWindow.document) {
      return;
    }
    const doc = aWindow.document;
    // NOTE: at `domwindowopened` time the window still holds its initial
    // about:blank document; browser.xhtml is loaded into it asynchronously.
    // We therefore remap from the `browser-delayed-startup-finished`
    // notification (see below), which fires once the chrome document is
    // fully loaded. Listeners attached here would be dropped on the
    // document swap, so no load-event retry is possible.
    if (doc.documentURI !== "chrome://browser/content/browser.xhtml") {
      return; // only touch main browser windows
    }

    let status = "";

    // 1) "Bookmark This Page": Ctrl+D -> Ctrl+B
    const addBookmarkKey = doc.getElementById("addBookmarkAsKb");
    if (addBookmarkKey) {
      addBookmarkKey.removeAttribute("data-l10n-id");
      addBookmarkKey.setAttribute("key", "b");
      addBookmarkKey.setAttribute("modifiers", "accel"); // Ctrl on Linux/Win
      status += "addBookmark=" + addBookmarkKey.getAttribute("key") +
        ":" + addBookmarkKey.getAttribute("modifiers") +
        " visible=" + aWindow.toolbar.visible;
    } else {
      status += "addBookmark=MISSING";
    }

    // 2) Free Ctrl+B by unbinding the bookmarks-sidebar toggle.
    const sidebarKey = doc.getElementById("viewBookmarksSidebarKb");
    if (sidebarKey) {
      sidebarKey.removeAttribute("data-l10n-id");
      sidebarKey.removeAttribute("key");
      status += " sidebar=" + (sidebarKey.getAttribute("key") || "(unbound)");
    } else {
      status += " sidebar=MISSING";
    }

    if (testSink) {
      testSink("remapped " + status + "\n");
    }

    // --- functional test hook ------------------------------------------------
    // When KBS_TEST_PANEL is set, watch for the "bookmark-added" notification
    // (fired by Browser:AddBookmarkAs), which proves the remapped Ctrl+B
    // keybinding actually triggers the add-bookmark command on keypress.
    try {
      const env2 = Cc["@mozilla.org/process/environment;1"]
        .getService(Ci.nsIEnvironment);
      if (env2.exists("KBS_TEST_PANEL")) {
        const timer = Cc["@mozilla.org/timer;1"].createInstance(Ci.nsITimer);
        let done = false;
        const obs = {
          observe(aSubject, aTopic) {
            if (aTopic === "bookmark-added" && !done) {
              done = true;
              if (testSink) testSink("bookmark-added-event\n");
              try { obsSvc.removeObserver(obs, "bookmark-added"); } catch (e) {}
              timer.cancel();
            }
          },
        };
        const obsSvc = Cc["@mozilla.org/observer-service;1"]
          .getService(Ci.nsIObserverService);
        obsSvc.addObserver(obs, "bookmark-added");
        // also poll for the edit-bookmark panel being opened (lazily
        // instantiated from a template on first use)
        let ticks = 0;
        timer.initWithCallback({
          notify() {
            ticks++;
            if (done) { timer.cancel(); return; }
            try {
              const panel = aWindow.document.getElementById("editBookmarkPanel");
              if (panel && panel.getAttribute("state") === "open" && !done) {
                done = true;
                if (testSink) testSink("bookmark-panel-open\n");
                timer.cancel();
                return;
              }
            } catch (e) { /* window gone */ }
            if (ticks > 120) {
              if (testSink) testSink("bookmark-added-never-fired\n");
              timer.cancel();
            }
          },
        }, 500, Ci.nsITimer.TYPE_REPEATING_SLACK);
        if (testSink) testSink("bookmark-added-watch started\n");
      }
    } catch (e) { /* ignore */ }
    // -------------------------------------------------------------------------
  }

  // Defensive: remap any browser window that already exists (autoconfig
  // normally runs before the first window is created).
  const wm = Cc["@mozilla.org/appshell/window-mediator;1"]
    .getService(Ci.nsIWindowMediator);
  const existing = wm.getEnumerator("navigator:browser");
  while (existing.hasMoreElements()) {
    remapWindow(existing.getNext());
  }

  // Remap every browser window opened from now on. The window's real chrome
  // document only becomes ready once "browser-delayed-startup-finished"
  // fires for it (subject = the ChromeWindow).
  const startupObserver = {
    observe(aSubject, aTopic) {
      if (aTopic === "browser-delayed-startup-finished") {
        remapWindow(aSubject);
      }
    },
  };
  observerService.addObserver(startupObserver, "browser-delayed-startup-finished");
})();
