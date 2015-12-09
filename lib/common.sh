#!/usr/bin/env bash

indent() {
  sed -u 's/^/       /'
}

error() {
  echo
  echo " !     ERROR: $*" | indent no_first_line_indent
  echo
  exit 1
}

error_return() {
  echo
  echo " !     ERROR: $*" | indent no_first_line_indent
  echo
  return 1
}

warning() {
  echo
  echo " !     WARNING: $*" | indent no_first_line_indent
  echo
}

warning_inline() {
  echo " !     WARNING: $*" | indent no_first_line_indent
}

status() {
  echo "-----> $*"
}

status_pending() {
  echo -n "-----> $*..."
}

status_done() {
  echo " done"
}

notice() {
  echo
  echo "NOTICE: $*" | indent
  echo
}

notice_inline() {
  echo "NOTICE: $*" | indent
}

cache_copy() {
  rel_dir=$1
  from_dir=$2
  to_dir=$3
  rm -rf $to_dir/$rel_dir
  if [ -d $from_dir/$rel_dir ]; then
    mkdir -p $to_dir/$rel_dir
    cp -pr $from_dir/$rel_dir/. $to_dir/$rel_dir
  fi
}


export_env_dir() {
    env_dir=$1
    whitelist_regex=${2:-''}
    blacklist_regex=${3:-'^(PATH|GIT_DIR|CPATH|CPPATH|LD_PRELOAD|LIBRARY_PATH|JAVA_OPTS)$'}
    if [ -d "$env_dir" ]; then
        for e in $(ls $env_dir); do
            echo "$e" | grep -E "$whitelist_regex" | grep -qvE "$blacklist_regex" &&
                export "$e=$(cat $env_dir/$e)"
            :
        done
    fi
}


create_build_log_file() {
  local name=${1}
  local buildLogFile="${1}-build.log"
  echo "" > $buildLogFile
  echo "$buildLogFile"
}

# sed -l basically makes sed replace and buffer through stdin to stdout
# so you get updates while the command runs and dont wait for the end
# e.g. sbt stage | indent
output() {
  local logfile="$1"
  local c='s/^/       /'

  case $(uname) in
      Darwin) tee -a "$logfile" | sed -l "$c";; # mac/bsd sed: -l buffers on line boundaries
      *)      tee -a "$logfile" | sed -u "$c";; # unix/gnu sed: -u unbuffered (arbitrary) chunks of data
  esac
}
