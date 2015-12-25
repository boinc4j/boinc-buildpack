#!/usr/bin/env bash

install_deps() {
  local buildDir=${1}
  local depNames=${2}

  ######### Borrowed from heroku-buildpack-apt
  APT_CACHE_DIR="$CACHE_DIR/apt/cache"
  APT_STATE_DIR="$CACHE_DIR/apt/state"
  APT_OPTIONS="-o debug::nolocking=true -o dir::cache=$APT_CACHE_DIR -o dir::state=$APT_STATE_DIR"

  mkdir -p "$APT_CACHE_DIR/archives/partial"
  mkdir -p "$APT_STATE_DIR/lists/partial"

  echo "-----> Installing dependencies... "
  apt-get $APT_OPTIONS update | indent
  apt-get $APT_OPTIONS -y --force-yes -d install --reinstall ${depNames} | indent

  for DEB in $(ls -1 $APT_CACHE_DIR/archives/*.deb); do
    dpkg -x $DEB $BUILD_DIR/.apt/
  done
}

create_deps_profile() {
  local buildDir=${1}
  mkdir -p $buildDir/.profile.d
  cat <<EOF >$buildDir/.profile.d/000_apt.sh
export PATH="\$HOME/.apt/usr/sbin:\$HOME/.apt/usr/bin:\$PATH"
export LD_LIBRARY_PATH="\$HOME/.apt/usr/lib/x86_64-linux-gnu:\$HOME/.apt/usr/lib/i386-linux-gnu:\$HOME/.apt/usr/lib:\$LD_LIBRARY_PATH"
export LIBRARY_PATH="\$HOME/.apt/usr/lib/x86_64-linux-gnu:\$HOME/.apt/usr/lib/i386-linux-gnu:\$HOME/.apt/usr/lib:\$LIBRARY_PATH"
export INCLUDE_PATH="\$HOME/.apt/usr/include:\$INCLUDE_PATH"
export CPATH="\$INCLUDE_PATH"
export CPPPATH="\$INCLUDE_PATH"
export PKG_CONFIG_PATH="\$HOME/.apt/usr/lib/x86_64-linux-gnu/pkgconfig:\$HOME/.apt/usr/lib/i386-linux-gnu/pkgconfig:\$HOME/.apt/usr/lib/pkgconfig:\$PKG_CONFIG_PATH"
EOF
}
