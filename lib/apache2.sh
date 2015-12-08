#!/usr/bin/env bash

apache_enable_cgid() {
  cat <<EOF >> $BUILD_DIR/project/boinc.httpd.conf
    LoadModule cgid_module /app/.heroku/php/libexec/mod_cgid.so
EOF
}

apache_add_index_php() {
  cat <<EOF >> $BUILD_DIR/project/boinc.httpd.conf
    DirectoryIndex index.php index.html
EOF
}
