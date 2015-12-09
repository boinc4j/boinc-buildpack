#!/usr/bin/env bash

DEFAULT_PLATFORMS="windows_intel86 windows_x86_64 i686-pc-linux-gnu x86_64-pc-linux-gnu i686-apple-darwin x86_64-apple-darwin"

install_boinc() {
  #### Download BOINC source
  echo "-----> Downloading BOINC source... "
  BOINC_DIR=${1}
  mkdir -p $BOINC_DIR
  curl --silent --retry 3 -L https://api.github.com/repos/BOINC/boinc/tarball/master | tar xzm -C $BOINC_DIR --strip-components=1

  #### Build BOINC from source
  echo "-----> Making BOINC Server... "
  cd $BOINC_DIR
  ./_autosetup
  ./configure --disable-client --disable-manager
  make
  cd - > /dev/null 2>&1
}

make_boinc_project() {
  local boincDir=${1}
  local boincProjectDir=${2}

  cd ${boincDir}

  # Whatever this is used for probably needs to be scrubed in profile.d
  export USER=$(whoami)

  # Never create the db, but still load the schema
  sed -i.bak s/cursor.execute\(\"create\ database/\#cursor.execute\(\"create\ database/g py/Boinc/database.py

  mysql -u $DATABASE_USERNAME -p$DATABASE_PASSWORD -h $DATABASE_HOST -e "describe app;" $DATABASE_NAME > /dev/null 2>&1
  if [ $? == 0 ]; then
    dbArgs="--no_db"
  fi

  ./tools/make_project --db_host $DATABASE_HOST --db_name $DATABASE_NAME \
                       --db_user $DATABASE_USERNAME --db_passwd $DATABASE_PASSWORD ${dbArgs:-} \
                       --user_name $(whoami) --no_query --srcdir $boincDir \
                       --project_root $boincProjectDir \
                       --url_base "https://$HEROKU_APP_NAME.herokuapp.com" \
                       --project_host "$HEROKU_APP_NAME.herokuapp.com" \
                       boinc $HEROKU_APP_NAME | indent

  if [ -n "${BOINC_OPS_USERNAME:-}" ] && [ -n "${BOINC_OPS_PASSWORD:-}" ]; then
    htpasswd -cb $boincProjectDir/html/ops/.htpasswd $BOINC_OPS_USERNAME $BOINC_OPS_PASSWORD | indent
  fi

  cd - > /dev/null 2>&1
}

add_project_xml() {
  local projectXml=${1}
  local projectName=${2}

  sed -i.bak s/example_app/${projectName}/g ${projectXml}
  sed -i.bak s/Example\ Application/${projectName}/g ${projectXml}
}

next_boinc_app_version() {
  local versionFile=${1}

  if [ ! -f $versionFile ]; then
    echo "0" > $versionFile
  fi

  local ver=$(head -n 1 ${versionFile})
  local nextVersion=${BOINC_APP_VERSION:-$((ver+1))}

  echo "$nextVersion" > ${versionFile}
  echo "${nextVersion}.0"
}

install_boinc_app() {
  local buildDir=${1}
  local boincDir=${2}
  local boincProjectDir=${3}
  local userBoincDir=${4}

  cd $boincProjectDir

  local nextVersion=$(next_boinc_app_version ${boincProjectDir}/app_version.txt)
  local appDir=apps/$HEROKU_APP_NAME

  add_project_xml $boincProjectDir/project.xml $HEROKU_APP_NAME
  bin/xadd | indent

  # Remove all previous versions
  rm -rf $appDir/*
  mkdir -p $appDir

  # Load the new version
  mv $userBoincDir/app $appDir/$nextVersion

  # Copy templates over
  cp $userBoincDir/templates/* templates/

  # Sign all files in the new version
  sign_files $boincDir $appDir/*

  yes | bin/update_versions | indent

  cd - > /dev/null 2>&1
  cd $buildDir

  create_start_script

  cd - > /dev/null 2>&1
}

sign_files() {
  local boincDir=${1}
  local appDir=${2}

  for platformDir in $(ls ${appDir}); do
    for file in $(find ${appDir}/${platformDir} -type f -follow -print); do
      $boincDir/lib/crypt_prog -sign $file keys/code_sign_private > $file.sig
    done
  done
}

create_start_script() {
  cat <<EOF > start-boinc.sh
#!/usr/bin/env bash

if [ "\$DYNO" = "web.1" ]; then
  echo "Starting daemons..."
  cd project/
  sed -i.bak s/\<host\>.*\</\<host\>\$(hostname)\</g config.xml
  bin/start &
  sleep 3
  tail /app/project/log_\$(hostname)/* &
fi

cd /app
vendor/bin/heroku-php-apache2 -C project/boinc.httpd.conf -p \$PORT
EOF
  cat <<EOF >> Procfile
web: sh start-boinc.sh
EOF
}
