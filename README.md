# Travis CI tools

Helper scripts for Dash Travis setup

### Usage

- Download and unpack the latest tarball
- Go to the unpacked directory
- Run `$ npm ci`
- Run `$ npm link`
- Use any of the following commands: `get-github-release-link`, `get-release-version`, `print-bells`

### get-github-release-link

Example: `$ get-github-release-link /full/path/to/package.json dashevo/dashman`

Arguments:

- Full path to a `package.json` containing `version` against which we have to check and download the latest release.
- Repository path in a form `org/repo-name` of which download latest release tarball.  

### get-release-version

Example: `$ get-release-version /full/path/to/package.json 42`

Arguments:

- Full path to a `package.json` containing `version` from which generate release version.
- **Optional** major version number to override the one calculated.

### print-bells

Just runs in a background and prints `bell` characters to `stdout`. Useful to keep Travis build alive.
