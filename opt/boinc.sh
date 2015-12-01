#!/usr/bin/env bash

set_jdbc_url() {
  local db_url=${1}

  local db_user=$(expr "$db_url" : "mysql://\(.\+\):\(.\+\)@")
  local db_prefix="mysql://${db_user}:"

  local db_pass=$(expr "$db_url" : "${db_prefix}\(.\+\)@")
  db_prefix="${db_prefix}${db_pass}@"

  local db_host_port=$(expr "$db_url" : "${db_prefix}\(.\+\)/")
  db_prefix="${db_prefix}${db_host_port}/"

  local db_name=$(expr "$db_url" : "${db_prefix}\(.\+\)?")

  export DATABASE_HOST="${db_host_port}"
  export DATABASE_USERNAME="${db_user}"
  export DATABASE_PASSWORD="${db_pass}"
  export DATABASE_NAME="${db_name}"
}

if [ -n "$DATABASE_URL" ]; then
  set_jdbc_url "$DATABASE_URL"
elif [ -n "$JAWSDB_URL" ]; then
  set_jdbc_url "$JAWSDB_URL"
elif [ -n "$CLEARDB_DATABASE_URL" ]; then
  set_jdbc_url "$CLEARDB_DATABASE_URL"
fi

cat <<EOF >>config.xml
<boinc>
  <config>
    <db_name>${DATABASE_NAME}</db_name>
    <db_host>${DATABASE_HOST}</db_host>
    <db_user>${DATABASE_USERNAME}</db_user>
    <db_passwd>${DATABASE_PASSWORD}</db_passwd>
  </config>
</boinc>
EOF
