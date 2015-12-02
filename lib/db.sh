#!/usr/bin/env bash

export_db_props() {
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
