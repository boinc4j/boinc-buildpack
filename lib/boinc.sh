#!/usr/bin/env bash

install_boinc() {
  #### Download BOINC source
  echo "-----> Downloading BOINC source... "
  BOINC_DIR=${1}
  mkdir -p $BOINC_DIR
  curl --silent --retry 3 -L https://api.github.com/repos/BOINC/boinc/tarball/master | tar xzm -C $BOINC_DIR --strip-components=1

  #### Build BOINC from source
  echo "-----> Making BOINC Server... "
  cd $BOINC_DIR
  ./_autosetup | indent
  ./configure --disable-client --disable-manager | indent
  make
  cd - > /dev/null 2>&1
}
