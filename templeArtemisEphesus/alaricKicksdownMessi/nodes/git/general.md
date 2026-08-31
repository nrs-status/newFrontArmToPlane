
--
title: Create new feature branch
creationDate: Sat Aug 29 07:15:26 PM GMT 2026
fuzzyAux: new feature branch switch 
body:
Create a new feature branch
`git branch feature/my-feature`
Create and switch to it
`git switch -c feature/my-feature`
Create and switch to it, basing it on a specific branch
`git switch -c feature/my-feature origin/main`
--
title: Switch to a particular branch
creationDate: Sat Aug 29 07:18:11 PM GMT 2026
fuzzyAux: switch branch
body:
Switch to a particular branch
`git switch feature/my-feature`
Create and switch to a particular branch
`git switch -c feature/my-feature`
--
title: Create a new worktree and a new branch for it at the same time
creationDate: Sat Aug 29 08:46:18 PM GMT 2026
body:
`git worktree add -b <new branch name> <new directory>`
--
title: Specify which files to commit along with a commit message
creationDate: Sat Aug 29 10:11:25 PM GMT 2026
body:
`git commit -m <msg> <potentially many filepaths, directories, or globs>`
--
title: unstage a file
creationDate: 2026-08-30 02:15
body: `git restore --staged <path to file>`
--
title: delete a branch
creationDate: 2026-08-30 21:20
body: `git branch -D <branch name>`
--
title: delete untracked files and directories
creationDate: 2026-08-31 05:15
body: `git clean -fd`
--
title: undo commits while keeping them in git history
creationDate: 2026-08-31 06:12
body: example:
```
git revert --no-commit <hash of some commit to remove>
git revert --no-commit <hash of some other commit to remove>
git commit -m <msg>
```
