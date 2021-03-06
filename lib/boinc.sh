#!/usr/bin/env bash

DEFAULT_PLATFORMS="windows_intel86 windows_x86_64 i686-pc-linux-gnu x86_64-pc-linux-gnu i686-apple-darwin x86_64-apple-darwin"

install_boinc() {
  #### Download BOINC source
  echo "-----> Downloading BOINC source... "
  BOINC_DIR=${1}
  mkdir -p $BOINC_DIR
  local boincVersion=${BOINC_VERSION:-"076755cb112ca0e62420f6ba7efa050dd53d24bc"}
  curl --silent --retry 3 -L https://api.github.com/repos/BOINC/boinc/tarball/${boincVersion}| tar xzm -C $BOINC_DIR --strip-components=1

  #### Build BOINC from source
  status "Making BOINC Server... "
  cd $BOINC_DIR
  ./_autosetup
  ./configure --disable-client --disable-manager
  make
  cd - > /dev/null 2>&1
}

boinc_make_project() {
  local boincDir=${1}
  local boincProjectDir=${2}

  cd ${boincDir}

  # Whatever this is used for probably needs to be scrubed in profile.d
  export USER=$(whoami)

  # Never create the db, but still load the schema
  sed -i.bak s/cursor.execute\(\"create\ database/\#cursor.execute\(\"create\ database/g py/Boinc/database.py

  echo "Testing database for existing schema..." | indent
  if [ -n "${DATABASE_PORT:-}" ]; then
    mysqlOpts="-h $DATABASE_HOST -P $DATABASE_PORT"
  else
    mysqlOpts="-h $DATABASE_HOST_PORT"
  fi
  tables=$(mysql -u $DATABASE_USERNAME -p$DATABASE_PASSWORD $mysqlOpts -e "show tables;" $DATABASE_NAME)
  if [[ "$tables" == *"app_version"* ]]; then
    dbArgs="--no_db"
  fi

  ./tools/make_project --db_host ${DATABASE_HOST_PORT} --db_name $DATABASE_NAME \
                       --db_user $DATABASE_USERNAME --db_passwd $DATABASE_PASSWORD ${dbArgs:-} \
                       --user_name $(whoami) --no_query --srcdir $boincDir \
                       --project_root $boincProjectDir \
                       --url_base "https://$HEROKU_APP_NAME.herokuapp.com" \
                       --project_host "$HEROKU_APP_NAME.herokuapp.com" \
                       boinc $HEROKU_APP_NAME | indent

  if [ -n "${BOINC_OPS_USERNAME:-}" ] && [ -n "${BOINC_OPS_PASSWORD:-}" ]; then
    htpasswd -cb $boincProjectDir/html/ops/.htpasswd $BOINC_OPS_USERNAME $BOINC_OPS_PASSWORD | indent
  fi

  #sed -i.bak s/REPLACE\ WITH\ PROJECT\ NAME/${BOINC_APP_NAME}/g \
  #    $boincProjectDir/html/project/project.inc

  cd - > /dev/null 2>&1
}

boinc_add_project_xml() {
  local projectXml=${1}
  local projectName=${2}

  sed -i.bak s/example_app/${projectName}/g ${projectXml}
  sed -i.bak s/Example\ Application/${projectName}/g ${projectXml}
}

boinc_next_app_version() {
  local versionFile=${1}

  if [ ! -f $versionFile ]; then
    echo "0" > $versionFile
  fi

  local ver=$(head -n 1 ${versionFile})
  local nextVersion=${BOINC_APP_VERSION:-$((ver+1))}

  echo "$nextVersion" > ${versionFile}
  echo "${nextVersion}.0"
}

boinc_prepare_downloads() {
  local boincProjectDir=${1}

  cd ${boincProjectDir}

  # TODO check for deprecated versions in DB and
  # delete only files associated with those

  if [ -z "${BOINC_KEEP_DOWNLOADS:-}" ]; then
    status "Deleting old download files..."
    rm -rf download/*
  fi

  echo "{}" > download/in.json
  ./bin/stage_file download/in.json

  # TODO copy download files over from userBoincDir
  # Copy downloads over
  #if [ -d $userBoincDir/download ]; then
  #  cp $userBoincDir/download/* download/
  #fi

  cd - > /dev/null 2>&1
}

boinc_install_app() {
  local buildDir=${1}
  local boincDir=${2}
  local boincProjectDir=${3}
  local userBoincDir=${4}

  cd $boincProjectDir

  local nextVersion=$(boinc_next_app_version ${boincProjectDir}/app_version.txt)
  local appDir=apps/$HEROKU_APP_NAME

  boinc_add_project_xml $boincProjectDir/project.xml $HEROKU_APP_NAME
  bin/xadd | indent

  # Remove all previous versions
  rm -rf $appDir/*
  mkdir -p $appDir

  # Load the new version
  mv $userBoincDir/app $appDir/$nextVersion

  # Copy templates over
  cp $userBoincDir/templates/* templates/

  if [ -d $userBoincDir/bin ]; then
    cp $userBoincDir/bin/* bin/
    chmod +x bin/*
  fi

  # Sign all files in the new version
  boinc_sign_files $boincDir $appDir/*

  cd - > /dev/null 2>&1
}

boinc_update_versions() {
  local boincProjectDir=${1}

  cd $boincProjectDir

  buildLogFile=$(create_build_log_file "update_versions")

  yes | bin/update_versions 2>&1 | output $buildLogFile

  handle_update_versions_errors $buildLogFile

  # Delete project files that are backed up by a URL
  rm -f download/*.zip

  cd - > /dev/null 2>&1
}

boinc_sign_files() {
  local boincDir=${1}
  local appDir=${2}

  for platformDir in $(ls ${appDir}); do
    for file in $(find ${appDir}/${platformDir} -type f -follow -print); do
      $boincDir/lib/crypt_prog -sign $file keys/code_sign_private > $file.sig
    done
  done
}

boinc_sub_project_name() {
  local boincProjectDir=${1}

  sed -i.bak \
    "s/REPLACE\ WITH\ PROJECT\ NAME/${BOINC_APP_NAME:-$HEROKU_APP_NAME}/g" \
    ${boincProjectDir}/html/project/project.inc
}

boinc_add_config() {
  local boincProjectDir=${1}
  local userBoincDir=${2}

  cd ${boincProjectDir}

  sed -i.bak '/\<daemons\>/,$d' config.xml

  if [ -f ${userBoincDir}/daemons.xml ]; then
      envsubst < ${userBoincDir}/daemons.xml >> config.xml
  else
    cat <<EOF >> config.xml
  <daemons>
    <daemon>
      <cmd>feeder -d 3 </cmd>
    </daemon>
    <daemon>
      <cmd>transitioner -d 3 </cmd>
    </daemon>
    <daemon>
     <cmd>file_deleter -d 2 --preserve_wu_files --preserve_result_files</cmd>
    </daemon>
    <daemon>
      <cmd>sample_trivial_validator -d 2 --app ${HEROKU_APP_NAME}</cmd>
    </daemon>
    <daemon>
      <cmd>sample_assimilator -d 2 --app ${HEROKU_APP_NAME}</cmd>
    </daemon>
  </daemons>
EOF
  fi

  echo "</boinc>" >> config.xml

  cd - > /dev/null 2>&1
}

boinc_create_start_script() {
  local buildDir=${1}
  local relBoincProjectDir=${2}

  cat <<EOF > $buildDir/start-boinc.sh
#!/usr/bin/env bash

bin/sync &

if [ "\$DYNO" = "web.1" ]; then
  echo "Starting daemons..."
  cd $relBoincProjectDir/
  sed -i.bak s/\<host\>.*\</\<host\>\$(hostname)\</g config.xml
  bin/start &
  sleep 3
  tail -f /app/$relBoincProjectDir/log_\$(hostname)/* | xargs -IX printf "[boinc] %s\n" X &
fi

cd /app
vendor/bin/heroku-php-apache2 -C $relBoincProjectDir/boinc.httpd.conf -p \$PORT
EOF

  cat <<EOF >> $buildDir/Procfile
web: sh start-boinc.sh
EOF
}
