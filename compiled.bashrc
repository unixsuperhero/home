# File: bash/settings/disable-ctrl_s-and-ctrl_q.bashrc

stty -ixon
stty -ixoff


# File: bash/rbenv.bashrc

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"


# File: bash/git/aliases_and_helper_functions.bashrc

# git aliases

alias gaa="git add --all"
alias gai="git add -i"
alias gb='git branch'
alias gc='git commit'
alias gco='git co'
alias gd='git diff'
alias gdc='git diff --cached'
alias gp='git push'
alias gpr='git pull --rebase'
alias grv='git remote -v'
alias gst='git status -s'
alias glod='git log --oneline --decorate --graph'
alias glodd='git log --oneline --decorate --graph -10'
alias glog='git log --oneline --decorate --graph --name-status'
alias glogg='git log --oneline --decorate --graph --name-status -10'
alias glr='git log --oneline --decorate --left-right'

alias gchist='(cd; git add */history; git commit -m "updating history files")'
alias gchistory='(cd; git add */history; git commit -m "updating history files")'

function gac() {
  git add --all

  if test ${#@} -gt 0; then
    git commit -m "$@"
  else
    git commit
  fi
}




#### WITH SOME SLOPPY PARTS


# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=5000
HISTFILESIZE=5000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar


# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac


# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi


# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# export PATH="/home/linuxbrew/.linuxbrew/bin:/home/toyota/bin:/home/toyota/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"

test -e ~/git.bashrc && source ~/git.bashrc

# export LDFLAGS="-L/home/linuxbrew/.linuxbrew/opt/isl@0.18/lib"
# export CPPFLAGS="-I/home/linuxbrew/.linuxbrew/opt/isl@0.18/include"
# export PKG_CONFIG_PATH="/home/linuxbrew/.linuxbrew/opt/isl@0.18/lib/pkgconfig"


# export PATH="/home/toyota/.rbenv/shims:${PATH}"
# export RBENV_SHELL=bash
# source "/usr/lib/rbenv/libexec/../completions/rbenv.bash"
# rbenv rehash 2>/dev/null
# rbenv() {
#   typeset command
#   command="$1"
#   if [ "$#" -gt 0 ]; then
#     shift
#   fi
#
#   case "$command" in
#   rehash|shell)
#     eval `rbenv "sh-$command" "$@"`;;
#   *)
#     command rbenv "$command" "$@";;
#   esac
# }

# --------------

mkcd() {
  for a; do
    mkdir -pv "$a"
    cd "$a"
  done
}

function =() { echo "$@" | bc -l; echo; }

if test -z $TMUX; then
  tmux new -A -s home
else
  export TERM="screen-256color"
fi


export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

export PATH="$HOME/bin:$PATH"

function gss() {
  if test $# -gt 0
  then
    (for a in $@; do
      git status -s | sed 's/...\(.* -> \)\{0,1\}//' | \egrep -i --color=never "$a"
    done) | sort -u
  else
    git status -s | sed 's/...\(.* -> \)\{0,1\}//'
  fi
}

# git aliases

alias gaa="git add --all"
alias gai="git add -i"
alias gb='git branch'
alias gc='git commit'
alias gco='git co'
alias gd='git diff'
alias gdc='git diff --cached'
alias gp='git push'
alias gpr='git pull --rebase'
alias grv='git remote -v'
alias gst='git status -s'
alias glod='git log --oneline --decorate --graph'
alias glodd='git log --oneline --decorate --graph -10'
alias glog='git log --oneline --decorate --graph --name-status'
alias glogg='git log --oneline --decorate --graph --name-status -10'
alias glr='git log --oneline --decorate --left-right'

alias gchist='(cd; git add */history; git commit -m "updating history files")'
alias gchistory='(cd; git add */history; git commit -m "updating history files")'

function gac() {
  git add --all

  if test ${#@} -gt 0; then
    git commit -m "$@"
  else
    git commit
  fi
}

export COLOR_RED="\033[0;31m"
export COLOR_YELLOW="\033[0;33m"
export COLOR_GREEN="\033[0;32m"
export COLOR_OCHRE="\033[38;5;95m"
export COLOR_BLUE="\033[0;34m"
export COLOR_WHITE="\033[0;37m"
export COLOR_RESET="\033[0m"

function git_prompt_info() {
  if git rev-parse --show-toplevel &>/dev/null
  then
    cr=`git rev-parse --symbolic-full-name HEAD`
    cb=${cr/refs?heads?/}
    statuses=$(ruby -e 'printf `git status -s`.lines.each.flat_map{|l| l[/^.../].strip.chars }.sort.uniq.join')
    printf '\033[1;33m[\033[0;33m%s\033[0m %s(%s)\033[1;33m]\033[0m' $cb $(git_color) $statuses
  fi
}

function git_color {
  local git_status="$(git status 2> /dev/null)"

  if [[ $git_status =~ "Changes not staged" ]]; then
    echo -e $COLOR_OCHRE
  elif [[ $git_status =~ "Untracked files" ]]; then
    echo -e $COLOR_RED
  elif [[ $git_status =~ "Your branch is ahead of" ]]; then
    echo -e $COLOR_YELLOW
  elif [[ $git_status =~ "nothing to commit" ]]; then
    echo -e $COLOR_GREEN
  else
    echo -e $COLOR_BLUE
  fi
}

### copy of old ps1:
### ----------------
# export PS1="${debian_chroot:+($debian_chroot)}\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "
export PS1="\[\e[1;32m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\] \$(git_prompt_info)\[\e[0m\] $ "

if test -z $TMUX; then
  tmux new -A -s home
else
  export TERM="screen-256color"
fi


# if [ -e ~/latest-vim-session.vim ]
# then
#   if ps awwux | egrep -i 'vim.*latest.vim.session' &>/dev/null
#   then
#     vim -S ~/latest-vim-session.vim
#   fi
# fi                                                                                                                                                                                                      

