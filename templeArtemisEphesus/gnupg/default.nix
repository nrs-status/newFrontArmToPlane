# gnupg packaged so that its `gpg-agent` automatically uses the pinentry
# from `pinentry-curses` (no user-facing gpg-agent.conf needed).
{
  pkgs,
  ...
}:
let
  # `pinentry-curses` installs its binary as `bin/pinentry-curses`, not
  # `bin/pinentry`, but it does not declare the `binaryPath` passthru that
  # gnupg consults when composing `--with-pinentry-pgm`. Add it, otherwise
  # the baked-in default would point at the nonexistent
  # `bin/pinentry` and gpg-agent would fall back to searching PATH.
  pinentryCurses = pkgs.pinentry-curses.overrideAttrs (old: {
    passthru = (old.passthru or { }) // {
      binaryPath = "bin/pinentry-curses";
    };
  });
in
# gnupg only passes `--with-pinentry-pgm=<path>` to ./configure when
# `guiSupport` is true (its default is `stdenv.hostPlatform.isDarwin`, i.e.
# false on Linux, where `pinentry` is normally ignored). Enabling
# `guiSupport` and pointing `pinentry` at `pinentryCurses` bakes the
# absolute store path of `pinentry-curses` into gpg-agent as its built-in
# default pinentry program, so gpg-agent uses it automatically.
pkgs.gnupg.override {
  guiSupport = true;
  pinentry = pinentryCurses;
}
