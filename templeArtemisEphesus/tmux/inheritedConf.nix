# inheritedConf.conf for the tmux package, generated at evaluation time
# instead of kept as a checked-in file.  Its original form was a plain
# text file with hardcoded /nix/store/... plugin paths from the machine
# it was written on; on any other store those paths do not exist, the
# plugins' run-shell lines fail silently at startup and nothing gets
# installed (no resurrect C-s / C-r bindings, no continuum autosave, no
# sysstat formats, no sensible defaults).  Generating the file here
# means the plugin paths are derived from the same nixpkgs the rest of
# the package builds against -- there is no store-path literal anywhere
# and nothing to keep in sync.

{ pkgs, sensiblePlugin, resurrectPlugin, continuumPlugin, sysstatPlugin }:
pkgs.writeText "inheritedConf.conf" ''
  # ============================================= #
  # Start with defaults from the Sensible plugin  #
  # --------------------------------------------- #
  run-shell ${sensiblePlugin}/share/tmux-plugins/sensible/sensible.tmux
  # ============================================= #

  set  -g default-terminal "tmux-256color"
  set  -g base-index      1
  setw -g pane-base-index 1

  new-session

  set -g status-keys vi
  set -g mode-keys   vi

  # rebind main key: C-a
  unbind C-b
  set -g prefix C-a
  bind -N "Send the prefix key through to the application" \
    C-a send-prefix

  set  -g mouse             off
  setw -g aggressive-resize off
  setw -g clock-mode-style  24
  set  -s escape-time       0
  set  -g history-limit     2000

  # ============================================= #
  # Plugins                                       #
  # --------------------------------------------- #

  # tmuxplugin-gruvbox
  # ---------------------
  # The gruvbox theme is sourced as `theme.conf' from the built package
  # (see ./default.nix, which installs it from pkgs.tmuxPlugins.gruvbox).

  # tmuxplugin-resurrect
  # ---------------------
  run-shell ${resurrectPlugin}/share/tmux-plugins/resurrect/resurrect.tmux

  # tmuxplugin-continuum
  # ---------------------
  set -g @continuum-restore 'on'
  set -g @continuum-save-interval '20' # minutes
  run-shell ${continuumPlugin}/share/tmux-plugins/continuum/continuum.tmux

  # tmuxplugin-sysstat
  # ---------------------
  set -g status-right "#{sysstat_cpu} | #{sysstat_mem} | #{sysstat_swap} | #{sysstat_loadavg} | #[fg=blue]#(echo $USER)#[default]@#H"
  run-shell ${sysstatPlugin}/share/tmux-plugins/sysstat/sysstat.tmux

  # ============================================= #

  # Enable mouse
  set -g mouse
  set -g mouse on

  # horizontal splits
  unbind-key |
  bind-key | split-window -h

  # vertical splits
  unbind-key _
  bind-key _ split-window

  # true color
  set -as terminal-overrides ",xterm-kitty,foot:RGB"

  # fix cursor shape in neovim
  set -ga terminal-overrides ',*:Ss=\E[%p1%d q:Se=\E[2 q'

  # swapping panes with arrow keys
  unbind-key ^Left
  bind-key ^Left swap-pane -U
  unbind-key ^Right
  bind-key ^Right swap-pane -D
  unbind-key ^Up
  bind-key ^Up swap-pane -U
  unbind-key ^Down
  bind-key ^Down swap-pane -D

  # use v and y in copy-mode
  bind-key -T copy-mode-vi 'v' send -X begin-selection
  bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel

  # ============================================= #
  # smart-splits.nvim (tmux multiplexer integration) #
  # --------------------------------------------- #
  # The neovim-side smart-splits.nvim plugin (see
  # templeArtemisEphesus/montezumaCirclesScroll/nixvimModules/plugins/smart-splits.nvim)
  # sets the pane-local `@pane-is-vim' option when it loads and unsets it when
  # neovim exits or suspends. These bindings therefore route the navigation and
  # resize keys either into the running nvim instance (where smart-splits
  # handles them, crossing the multiplexer boundary at nvim split edges) or to
  # tmux pane selection / resizing.

  # Smart pane switching with awareness of Neovim splits.
  bind-key -n C-h if -F "#{@pane-is-vim}" 'send-keys C-h'  'select-pane -L'
  bind-key -n C-j if -F "#{@pane-is-vim}" 'send-keys C-j'  'select-pane -D'
  bind-key -n C-k if -F "#{@pane-is-vim}" 'send-keys C-k'  'select-pane -U'
  bind-key -n C-l if -F "#{@pane-is-vim}" 'send-keys C-l'  'select-pane -R'

  # Smart pane resizing with awareness of Neovim splits (step size 3 matches
  # smart-splits.nvim's `default_amount').
  bind-key -n M-h if -F "#{@pane-is-vim}" 'send-keys M-h' 'resize-pane -L 3'
  bind-key -n M-j if -F "#{@pane-is-vim}" 'send-keys M-j' 'resize-pane -D 3'
  bind-key -n M-k if -F "#{@pane-is-vim}" 'send-keys M-k' 'resize-pane -U 3'
  bind-key -n M-l if -F "#{@pane-is-vim}" 'send-keys M-l' 'resize-pane -R 3'

  # Same navigation from within copy-mode.
  bind-key -T copy-mode-vi 'C-h' select-pane -L
  bind-key -T copy-mode-vi 'C-j' select-pane -D
  bind-key -T copy-mode-vi 'C-k' select-pane -U
  bind-key -T copy-mode-vi 'C-l' select-pane -R
''
