# Git version checking
set -l git_version (git version 2>/dev/null | string split ' ')[3]

# Function to compare version numbers
function version_at_least --argument-names required_version current_version
    set -l required_parts (string split '.' -- $required_version)
    set -l current_parts (string split '.' -- $current_version)
    for i in (seq 1 (math "max((count $required_parts), (count $current_parts))"))
        set -l required_part (math (or $required_parts[$i] 0))
        set -l current_part (math (or $current_parts[$i] 0))
        if test $current_part -gt $required_part
            return 0
        else if test $current_part -lt $required_part
            return 1
        end
    end
    return 0
end

#
# Functions Current
# (sorted alphabetically by function name)
# (order should follow README)
#

# Function to get the name of the current branch
function git_current_branch
  git rev-parse --abbrev-ref HEAD
end

function current_branch
  git_current_branch
end

# Check for develop and similarly named branches
function git_develop_branch
  if not git rev-parse --git-dir >/dev/null 2>&1
    return
  end
  for branch in dev devel develop development
    if git show-ref -q --verify refs/heads/$branch
      echo $branch
      return 0
    end
  end
  echo develop
  return 1
end

# Check if main exists and use instead of master
function git_main_branch
  if not git rev-parse --git-dir >/dev/null 2>&1
    return
  end
  for ref in \
    refs/heads/main refs/heads/trunk refs/heads/mainline refs/heads/default refs/heads/stable refs/heads/master \
    refs/remotes/origin/main refs/remotes/origin/trunk refs/remotes/origin/mainline refs/remotes/origin/default refs/remotes/origin/stable refs/remotes/origin/master \
    refs/remotes/upstream/main refs/remotes/upstream/trunk refs/remotes/upstream/mainline refs/remotes/upstream/default refs/remotes/upstream/stable refs/remotes/upstream/master
    if git show-ref -q --verify $ref
      echo (basename $ref)
      return 0
    end
  end
  echo master
  return 1
end

function grename
  if test (count $argv) -ne 2
    echo "Usage: grename old_branch new_branch"
    return 1
  end
  # Rename branch locally
  git branch -m $argv[1] $argv[2]
  # Rename branch in origin remote
  if git push origin :$argv[1]
    git push --set-upstream origin $argv[2]
  end
end

#
# Functions Work in Progress (WIP)
# (sorted alphabetically by function name)
# (order should follow README)
#

# Similar to `gunwip` but recursive "Unwips" all recent `--wip--` commits not just the last one
function gunwipall
  set -l _commit (git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H)
  # Check if a commit without "--wip--" was found and it's not the same as HEAD
  if test "$_commit" != (git rev-parse HEAD)
    git reset $_commit; or return 1
  end
end

# Warn if the current branch is a WIP
function work_in_progress
  if git -c log.showSignature=false log -n 1 2>/dev/null | grep -- "--wip--" >/dev/null
    echo "WIP!!"
  end
end

#
# Aliases and Functions
# (sorted alphabetically by command)
# (order should follow README)
#

function grt
  cd (git rev-parse --show-toplevel 2>/dev/null; or echo .)
end

function ggpnp
  if test (count $argv) -eq 0
    ggl; and ggp
  else
    ggl $argv; and ggp $argv
  end
end

alias ggpur='ggu'

function g
  command git $argv
end

function ga
  git add $argv
end

function gaa
  git add --all $argv
end

function gapa
  git add --patch $argv
end

function gau
  git add --update $argv
end

function gav
  git add --verbose $argv
end

function gwip
  git add -A
  git rm (git ls-files --deleted) 2>/dev/null
  git commit --no-verify --no-gpg-sign --message "--wip-- [skip ci]"
end

alias gam='git am'
alias gama='git am --abort'
alias gamc='git am --continue'
alias gamscp='git am --show-current-patch'
alias gams='git am --skip'
alias gap='git apply'
alias gapt='git apply --3way'
alias gbs='git bisect'
alias gbsb='git bisect bad'
alias gbsg='git bisect good'
alias gbsn='git bisect new'
alias gbso='git bisect old'
alias gbsr='git bisect reset'
alias gbss='git bisect start'
alias gbl='git blame -w'
alias gb='git branch'
alias gba='git branch --all'
alias gbd='git branch --delete'
alias gbD='git branch --delete --force'

function gbda
  set -l main_branch (git_main_branch)
  set -l develop_branch (git_develop_branch)
  set -l pattern "^([+*]|\\s*($main_branch|$develop_branch)\\s*\$)"
  git branch --no-color --merged | grep -vE "$pattern" | xargs git branch --delete 2>/dev/null
end

# Copied and modified from James Roeder (jmaroeder) under MIT License
function gbds
  set -l default_branch (git_main_branch)
  if test $status -ne 0
    set default_branch (git_develop_branch)
  end
  git for-each-ref refs/heads/ "--format=%(refname:short)" | while read branch
    set -l merge_base (git merge-base $default_branch $branch)
    set -l tree_commit (git commit-tree (git rev-parse "$branch^{tree}") -p $merge_base -m _)
    if git cherry $default_branch $tree_commit | grep -q "^-" 
      git branch -D $branch
    end
  end
end

function gbgd
  env LANG=C git branch --no-color -vv | grep ": gone\\]" | cut -c 3- | awk '{print $1}' | xargs git branch -d
end

function gbgD
  env LANG=C git branch --no-color -vv | grep ": gone\\]" | cut -c 3- | awk '{print $1}' | xargs git branch -D
end

alias gbm='git branch --move'
alias gbnm='git branch --no-merged'
alias gbr='git branch --remote'

function ggsup
  git branch --set-upstream-to=origin/(git_current_branch)
end

function gbg
  env LANG=C git branch -vv | grep ": gone\\]"
end

alias gco='git checkout'
alias gcor='git checkout --recurse-submodules'
alias gcb='git checkout -b'
alias gcB='git checkout -B'

function gcd
  git checkout (git_develop_branch)
end

function gcm
  git checkout (git_main_branch)
end

alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gclean='git clean --interactive -d'
alias gcl='git clone --recurse-submodules'
alias gclf='git clone --recursive --shallow-submodules --filter=blob:none --also-filter-submodules'

function gccd
  set -l repo ''
  for arg in $argv
    if string match -r '^(ssh://|git://|ftp://|ftps://|http://|https://|.*@).*(\.git)?$' $arg
      set repo $arg
    end
  end
  git clone --recurse-submodules $argv; or return
  if test -d "$argv[-1]"
    cd "$argv[-1]"
  else
    cd (string replace -r '\.git/?$' '' (basename $repo))
  end
end

alias gcam='git commit --all --message'
alias gcas='git commit --all --signoff'
alias gcasm='git commit --all --signoff --message'
alias gcs='git commit --gpg-sign'
alias gcss='git commit --gpg-sign --signoff'
alias gcssm='git commit --gpg-sign --signoff --message'
alias gcmsg='git commit --message'
alias gcsm='git commit --signoff --message'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias 'gca!'='git commit --verbose --all --amend'
alias 'gcan!'='git commit --verbose --all --no-edit --amend'
alias 'gcans!'='git commit --verbose --all --signoff --no-edit --amend'
alias 'gcann!'='git commit --verbose --all --date=now --no-edit --amend'
alias 'gc!'='git commit --verbose --amend'
alias gcn='git commit --verbose --no-edit'
alias 'gcn!'='git commit --verbose --no-edit --amend'
alias gcf='git config --list'
alias gdct='git describe --tags (git rev-list --tags --max-count=1)'
alias gd='git diff'
alias gdca='git diff --cached'
alias gdcw='git diff --cached --word-diff'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'

function gdv
  git diff -w $argv | view -
end

alias gdup='git diff @{upstream}'

function gdnolock
  git diff $argv ':(exclude)package-lock.json' ':(exclude)*.lock'
end

alias gdt='git diff-tree --no-commit-id --name-only -r'
alias gf='git fetch'

if version_at_least 2.8 $git_version
  alias gfa='git fetch --all --tags --prune --jobs=10'
else
  alias gfa='git fetch --all --tags --prune'
end

alias gfo='git fetch origin'
alias gg='git gui citool'
alias gga='git gui citool --amend'
alias ghh='git help'
alias glgg='git log --graph'
alias glgga='git log --graph --decorate --all'
alias glgm='git log --graph --max-count=10'
alias glods='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset" --date=short'
alias glod='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset"'
alias glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
alias glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'
alias glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'

# Pretty log messages
function glp
  if test (count $argv) -gt 0
    git log --pretty=$argv[1]
  end
end

alias glg='git log --stat'
alias glgp='git log --stat --patch'
alias gignored='git ls-files -v | grep "^[[:lower:]]"'
alias gfg='git ls-files | grep'
alias gm='git merge'
alias gma='git merge --abort'
alias gmc='git merge --continue'
alias gms='git merge --squash'
alias gmff='git merge --ff-only'

function gmom
  git merge origin/(git_main_branch)
end

function gmum
  git merge upstream/(git_main_branch)
end

alias gmtl='git mergetool --no-prompt'
alias gmtlvim='git mergetool --no-prompt --tool=vimdiff'

alias gl='git pull'
alias gpr='git pull --rebase'
alias gprv='git pull --rebase -v'
alias gpra='git pull --rebase --autostash'
alias gprav='git pull --rebase --autostash -v'

function ggu
  set -l b (git_current_branch)
  git pull --rebase origin $argv $b
end

function gprom
  git pull --rebase origin (git_main_branch)
end

function gpromi
  git pull --rebase=interactive origin (git_main_branch)
end

function gprum
  git pull --rebase upstream (git_main_branch)
end

function gprumi
  git pull --rebase=interactive upstream (git_main_branch)
end

function ggpull
  git pull origin (git_current_branch)
end

function ggl
  if test (count $argv) -gt 0
    git pull origin $argv
  else
    set -l b (git_current_branch)
    git pull origin $b
  end
end

function gluc
  git pull upstream (git_current_branch)
end

function glum
  git pull upstream (git_main_branch)
end

alias gp='git push'
alias gpd='git push --dry-run'

function ggf
  set -l b (git_current_branch)
  git push --force origin $argv $b
end

alias 'gpf!'='git push --force'

if version_at_least 2.30 $git_version
  alias gpf='git push --force-with-lease --force-if-includes'
else
  alias gpf='git push --force-with-lease'
end

function ggfl
  set -l b (git_current_branch)
  git push --force-with-lease origin $argv $b
end

function gpsup
  git push --set-upstream origin (git_current_branch)
end

if version_at_least 2.30 $git_version
  function gpsupf
    git push --set-upstream origin (git_current_branch) --force-with-lease --force-if-includes
  end
else
  function gpsupf
    git push --set-upstream origin (git_current_branch) --force-with-lease
  end
end

alias gpv='git push --verbose'
alias gpoat='git push origin --all && git push origin --tags'
alias gpod='git push origin --delete'

function ggpush
  git push origin (git_current_branch)
end

function ggp
  if test (count $argv) -gt 0
    git push origin $argv
  else
    set -l b (git_current_branch)
    git push origin $b
  end
end

alias gpu='git push upstream'
alias grb='git rebase'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'
alias grbi='git rebase --interactive'
alias grbo='git rebase --onto'
alias grbs='git rebase --skip'

function grbd
  git rebase (git_develop_branch)
end

function grbm
  git rebase (git_main_branch)
end

function grbom
  git rebase origin/(git_main_branch)
end

function grbum
  git rebase upstream/(git_main_branch)
end

alias grf='git reflog'
alias gr='git remote'
alias grv='git remote --verbose'
alias gra='git remote add'
alias grrm='git remote remove'
alias grmv='git remote rename'
alias grset='git remote set-url'
alias grup='git remote update'
alias grh='git reset'
alias gru='git reset --'
alias grhh='git reset --hard'
alias grhk='git reset --keep'
alias grhs='git reset --soft'
alias gpristine='git reset --hard && git clean --force -dfx'
alias gwipe='git reset --hard && git clean --force -df'

function groh
  git reset origin/(git_current_branch) --hard
end

alias grs='git restore'
alias grss='git restore --source'
alias grst='git restore --staged'
alias gunwip='git rev-list --max-count=1 --format="%s" HEAD | grep -q "\--wip--" && git reset HEAD~1'
alias grev='git revert'
alias greva='git revert --abort'
alias grevc='git revert --continue'
alias grm='git rm'
alias grmc='git rm --cached'
alias gcount='git shortlog --summary --numbered'
alias gsh='git show'
alias gsps='git show --pretty=short --show-signature'
alias gstall='git stash --all'
alias gstaa='git stash apply'
alias gstc='git stash clear'
alias gstd='git stash drop'
alias gstl='git stash list'
alias gstp='git stash pop'

if version_at_least 2.13 $git_version
  alias gsta='git stash push'
else
  alias gsta='git stash save'
end

alias gsts='git stash show --patch'
alias gst='git status'
alias gss='git status --short'
alias gsb='git status --short --branch'
alias gsi='git submodule init'
alias gsu='git submodule update'
alias gsd='git svn dcommit'

function git-svn-dcommit-push
  git svn dcommit && git push github (git_main_branch):svntrunk
end

alias gsr='git svn rebase'
alias gsw='git switch'
alias gswc='git switch --create'

function gswd
  git switch (git_develop_branch)
end

function gswm
  git switch (git_main_branch)
end

alias gta='git tag --annotate'
alias gts='git tag --sign'
alias gtv='git tag | sort -V'
alias gignore='git update-index --assume-unchanged'
alias gunignore='git update-index --no-assume-unchanged'
alias gwch='git whatchanged -p --abbrev-commit --pretty=medium'
alias gwt='git worktree'
alias gwta='git worktree add'
alias gwtls='git worktree list'
alias gwtmv='git worktree move'
alias gwtrm='git worktree remove'
alias gstu='gsta --include-untracked'

function gtl
  git tag --sort=-v:refname -n --list "$argv*"
end

alias gk='gitk --all --branches &'
alias gke='gitk --all (git log --walk-reflogs --pretty=%h) &'

# Logic for adding warnings on deprecated aliases
set -l deprecated_aliases \
  gup gpr \
  gupv gprv \
  gupa gpra \
  gupav gprav \
  gupom gprom \
  gupomi gpromi

for i in (seq 1 2 (count $deprecated_aliases))
  set old_alias $deprecated_aliases[$i]
  set new_alias $deprecated_aliases[(math $i + 1)]
  function $old_alias
    printf "%s\n" "[fish] '$old_alias' is a deprecated alias, using '$new_alias' instead."
    $new_alias $argv
  end
end
