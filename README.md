# BOINC Buildpack for Heroku

This is a [Heroku buildpack](https://devcenter.heroku.com/articles/buildpacks)
for the [BOINC server](http://boinc.berkeley.edu/). It allow you to run a
BOINC application on a Platform-as-a-Service (PaaS).

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

You may have directories for any platforms you with, but those directories will
need to contain your application(s). It is not recommend that you keep binaries
in these directories. Instead, binaries should be stored on S3 or some other
block storage server. Then you can configure those files in your [`version.xml`
with the `<url>` element](http://boinc.berkeley.edu/trac/wiki/AppVersionNew).
The `version.xml` should go in these platform directories.

The templates directory must contain
your template files, just as it would on the BOINC server.

Once you've create this project, install the [Heroku toolbelt](http://toolbelt.heroku.com), create a Heroku account, and login with the `heroku login` command.

Then initialize a Git repo for you project:

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