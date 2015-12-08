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

add_project_xml() {
  local projectXml=${1}
  local projectName=${2}

  sed -i.bak s/example_app/${projectName}/g ${projectXml}
  sed -i.bak s/Example\ Application/${projectName}/g ${projectXml}
}

add_wrapper_bin() {
  local appDir=${1}
  local platform=${2}
  local wrapperVersion="26014"
  local platformDir=${appDir}/${platform}

  curl -O -s -L http://boinc.berkeley.edu/dl/wrapper_${wrapperVersion}_${platform}.zip
  unzip wrapper_${wrapperVersion}_${platform}.zip
  mkdir -p ${platformDir}
  mv wrapper_${wrapperVersion}_${platform} ${platformDir}/wrapper_${wrapperVersion}_${platform}
  rm -f wrapper_${wrapperVersion}_${platform}.zip

  sed -i.bak -e "s/<\/version>//g" ${platformDir}/version.xml
  cat <<EOF >> ${platformDir}/version.xml
   <file>
      <physical_name>wrapper_${wrapperVersion}_${platform}</physical_name>
      <main_program/>
      <copy_file/>
   </file>
   <is_wrapper/>
</version>
EOF
}

add_app_files() {
    local targetFiles=${1}
    local appDir=${2}

    if [ -f version.xml ] && grep -q "<main_program/>" version.xml; then
      # huh?
      echo "Non-wrapper apps are not yet supported"
      exit 1
    elif [ -f version.xml ]; then
      for platform in $PLATFORMS; do
        mv $targetFiles/$platform $appDir/$platform
        app_wrapper_bins $appDir $platform
      done
    else
      echo "ERROR: no version.xml in $platform"
      exit 1
    fi
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
