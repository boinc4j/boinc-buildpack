#!/usr/bin/env bash

handle_update_versions_errors() {
  local log_file="$1"

  if grep -qi "BOINC files are immutable" "$log_file"; then
    error "If you change the contents of a file, you must also change it's name. That's the way BOINC works."
  fi
}
