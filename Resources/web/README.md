VLC iOS WebUI
==============

This Web UI is build using MontageJS a web framework aiming at maintable rich single page web applications.


Setup
---
For now I've decided to keep the `node_module` folder out of the repository. Therefore you need to run:

```
npm install .
```

This will fetch Montage's dependencies.
This is very likely to change later, when I'll be more certain on the dependencies the `node_module` will be checkout, which by the way is the recommanded solution by npm.



Building the app for production
---

MontageJS is a full browser solution and **does not** require (ahah) node or npm to run.
Nevertheless you would have to be a full not to use node/npm during developpement as MontageJS comes with great tool using the node/npm world.


```
mop

```

JSHint and code sanity
---
JSHint is your friend, not only does it prevent you from commiting ugly code that will get laught at, its syntax checking will spots your misstype.
To install jshint:

```
npm install -g jshint
```

Layout
------

The template contains the following files and directories:

* `index.html`
* `package.json` – Describes your app and its dependencies
* `README.markdown` – This readme.
* `ui/` – Directory containing all the UI .reel directories.
  * `main.reel` – The main interface component
* `core/` – Directory containing all core code for your app.
* `node_modules/` – Directory containing all npm packages needed, including Montage. Any packages here must be included as `dependencies` in `package.json` for the Montage require to find them.
* `assets/` – Assets such as global styles and images for your app
* `test/` – Directory containing tests for your app.
  * `all.js` – Module that point the test runner to all your jasmine specs.
* `run-tests.html` – Page to run jasmine tests manually in your browser

Create the following directories if you need them:

* `locale/` – Directory containing localized content.
* `scripts/` – Directory containing other JS libraries. If a library doesn’t support the CommonJS "exports" object it will need to be loaded through a `<script>` tag.
