{ pkgs }:
''

[core]
	page = "${pkgs.delta}"

[delta]
	features = "line-numbers"
	syntax-theme = "gruvbox-dark"

[diff]
	algorithm = "histogram"
	colorMoved = "default"
	tool = "nvimdiff"

[credential "https://github.com"]
	username = nrs-status
	helper = "store --file /run/secrets/git/github/nrs-status/credential"

[user]
	name = nrs-status
	email = sebaarsim@gmail.com

[github]
	user = nrs-status

[url "https://github.com/"]
	insteadOf = git@github.com:

[merge]
    conflictstyle = "zdiff3"
    keepbackup = true

[pull]
    rebase = "true"

[push]
    default = "current"
    followtags = true

[rebase]
    autosquash = true
''
