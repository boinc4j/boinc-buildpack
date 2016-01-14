# BOINC Buildpack for Heroku

This is a [Heroku buildpack](https://devcenter.heroku.com/articles/buildpacks)
for the [BOINC server](http://boinc.berkeley.edu/). It allows you to run a
BOINC application on the Heroku Platform-as-a-Service (PaaS).

## Usage

You must create a project with this directory structure at a minimum:

```
boinc
├── app
│   ├── i686-apple-darwin
│   ├── i686-pc-linux-gnu
│   ├── windows_intelx86
│   ├── windows_x86_64
│   ├── x86_64-apple-darwin
│   └── x86_64-pc-linux-gnu
└── templates
```

You may have directories for any platforms you wish, but those directories will
need to contain your application(s). It is not recommend that you keep binaries
in these directories. Instead, binaries should be stored on S3 or some other
block storage server. Then you can configure those files in your [`version.xml`
with the `<url>` element](http://boinc.berkeley.edu/trac/wiki/AppVersionNew).
The `version.xml` should go in these platform directories.

The templates directory must contain
your template files, just as it would on the BOINC server.

Once you've create this project, install the [Heroku toolbelt](http://toolbelt.heroku.com), create a Heroku account, and login with the `heroku login` command.

Then initialize a Git repo for your project:

```
$ git init
$ git add .
$ git commit -m "first"
```

Now create your Heroku app (but replace <app_name> with your choosen name):

```
$ heroku create <app_name> --buildpack https://github.com/boinc4j/boinc-buildpack
$ heroku addons:create jawsdb:kitefin
$ heroku config:set HEROKU_APP_NAME="<app_name>"
$ heroku config:set BOINC_APP_NAME="English Name for App"
$ heroku config:set BOINC_OPS_USERNAME="admin"
$ heroku config:set BOINC_OPS_PASSWORD="secret"
```

Finally, push your app to Heroku:

```
$ git push heroku master
```

## Daemons

Daemons can be configured by adding a `daemons.xml` file to the `boinc/`
directory in the Git repo. This file will be added to the default
`config.xml` on the BOINC server. It may look something like this:

```xml
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
```

## License

MIT