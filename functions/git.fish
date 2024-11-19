# Git version checking
function git_version
    echo (string split ' ' (git version 2>/dev/null) | tail -n1)
end

# The name of the current branch
function current_branch
    git_current_branch
end

# Check for develop and similarly named branches
function git_develop_branch
    if not git rev-parse --git-dir &>/dev/null
        return 1
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
    if not git rev-parse --git-dir &>/dev/null
        return 1
    end

    for ref in refs/{heads,remotes/{origin,upstream}}/{main,trunk,mainline,default,stable,master}
        if git show-ref -q --verify $ref
            echo (string split -r '/' $ref | head -n1)
            return 0
        end
    end

    echo master
    return 1
end

# Rename a branch
function grename
    if test -z "$argv[1]" -o -z "$argv[2]"
        echo "Usage: grename old_branch new_branch"
        return 1
    end

    git branch -m $argv[1] $argv[2]
    if git push origin :"$argv[1]"
        git push --set-upstream origin $argv[2]
    end
end

# "Unwip" all recent WIP commits
function gunwipall
    set commit (git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H)

    if test "$commit" != (git rev-parse HEAD)
        git reset $commit || return 1
    end
end

# Warn if the current branch is a WIP
function work_in_progress
    git -c log.showSignature=false log -n 1 2>/dev/null | grep -q -- "--wip--" && echo "WIP!!"
end

# Go to the top-level directory of the current repository
alias grt 'cd (git rev-parse --show-toplevel || echo .)'

# Git aliases (adapted for Fish)
alias g 'git'
alias ga 'git add'
alias gaa 'git add --all'
alias gst 'git status'
alias gco 'git checkout'
alias gcb 'git checkout -b'
alias gcm 'git checkout (git_main_branch)'
alias gpush 'git push origin (current_branch)'
alias gpull 'git pull origin (current_branch)'

# Fetch all and prune
function git_version_ge
    # Split the versions into arrays
    set -l v1 (string split '.' $argv[1])
    set -l v2 (string split '.' $argv[2])

    # Determine the maximum length of the arrays
    set -l len1 (count $v1)
    set -l len2 (count $v2)

    set -l maxlen
    if test $len1 -gt $len2
        set maxlen $len1
    else
        set maxlen $len2
    end

    for i in (seq $maxlen)
        # Get the version component or default to 0 if missing
        set -l part1 0
        if test $i -le $len1
            set part1 $v1[$i]
        end

        set -l part2 0
        if test $i -le $len2
            set part2 $v2[$i]
        end

        # Compare the components
        if test (math $part1) -gt (math $part2)
            return 0
        else if test (math $part1) -lt (math $part2)
            return 1
        end
    end

    # If all parts are equal
    return 0
end

# Use the updated version comparison function
if git_version_ge (git_version) 2.8
    alias gfa 'git fetch --all --tags --prune --jobs=10'
else
    alias gfa 'git fetch --all --tags --prune'
end
