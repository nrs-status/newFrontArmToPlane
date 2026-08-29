// bookmark-remap.js
// Firefox autoconfig script: remaps the "Add bookmark" keybinding.
//
//   Ctrl+D  (add bookmark)   ->  Ctrl+B
//   Ctrl+B  (bookmarks sidebar) -> unbound, so it cannot shadow the new mapping
//
// This file is loaded by Firefox's autoconfig machinery
// (defaults/pref/autoconfig.js -> general.config.filename) and therefore runs
// once at startup with chrome (privileged) privileges, before any browser
// window exists. The first line of this file MUST be a comment.

(function () {
  "use strict";

  // Autoconfig scripts run in a privileged sandbox where `Components` is
  // available. Grab the services we need without hard imports, so this keeps
  // working across Firefox versions (JSM removals, etc.).
  const { classes: Cc, interfaces: Ci } = Components;

  const windowWatcher = Cc["@mozilla.org/embedcomp/window-watcher;1"]
    .getService(Ci.nsIWindowWatcher);
  const windowMediator = Cc["@mozilla.org/appshell/window-mediator;1"]
    .getService(Ci.nsIWindowMediator);

  // The key element for "Bookmark This Page" lives in browser.xhtml as:
  //   <key id="addBookmarkAsKb" data-l10n-id="bookmark-this-page-shortcut"
  //        command="Browser:AddBookmarkAs" modifiers="accel"/>
  // The literal key character ("D") comes from Fluent localization, so we must
  // drop data-l10n-id as well, otherwise Fluent would restore "D" on reload.
  //
  // Ctrl+B is already taken by the bookmarks sidebar:
  //   <key id="viewBookmarksSidebarKb" data-l10n-id="bookmark-show-sidebar-shortcut"
  //        modifiers="accel"/>   (.key = B)
  // We unbind it so the new mapping is unambiguous.
  function remapWindow(aWindow) {
    if (!aWindow || !aWindow.document) {
      return;
    }

    const doc = aWindow.document;
    if (doc.readyState !== "complete") {
      // domwindowopened fires before the chrome document is parsed; retry on load.
      aWindow.addEventListener("load", () => remapWindow(aWindow), { once: true });
      return;
    }

    // Only touch main browser windows.
    if (doc.documentURI !== "chrome://browser/content/browser.xhtml") {
      return;
    }

    // 1) "Bookmark This Page": Ctrl+D -> Ctrl+B
    const addBookmarkKey = doc.getElementById("addBookmarkAsKb");
    if (addBookmarkKey) {
      addBookmarkKey.removeAttribute("data-l10n-id");
      addBookmarkKey.setAttribute("key", "b");
      addBookmarkKey.setAttribute("modifiers", "accel"); // Ctrl (Win/Linux) / Cmd (macOS)
    }

    // 2) Free Ctrl+B by unbinding the bookmarks-sidebar toggle.
    const sidebarKey = doc.getElementById("viewBookmarksSidebarKb");
    if (sidebarKey) {
      sidebarKey.removeAttribute("data-l10n-id");
      sidebarKey.removeAttribute("key");
    }
  }

  // Defensive: remap any browser window that already exists (autoconfig
  // normally runs before the first window is created).
  const existingWindows = windowMediator.getEnumerator("navigator:browser");
  while (existingWindows.hasMoreElements()) {
    remapWindow(existingWindows.getNext());
  }

  // Remap every browser window opened from now on.
  windowWatcher.registerNotification({
    observe(aSubject, aTopic) {
      if (aTopic === "domwindowopened") {
        remapWindow(aSubject);
      }
    },
  });
})();
