# Releases

Full public release packaging is not enabled in this repository at the moment.

Reason:

* the BinDiff GUI build requires the proprietary `yFiles` libraries
* those dependencies are not present in this repository and are not
  redistributable as part of the public source tree

Because of that, this repository currently supports:

* public multi-platform CI for the native open-source components
* optional local work on packaging scripts
* optional local/private release automation once the required proprietary
  dependencies are available

This repository does **not** currently publish complete GitHub Releases such as
`.msi`, `.dmg`, or `.deb` artifacts from public CI.

## Current CI scope

The active workflow is:

* `.github/workflows/cmake.yml`

It validates the public native build matrix on:

* Windows `x64`
* Windows `arm64`
* macOS `x64`
* macOS `arm64`
* Linux `x64`
* Linux `arm64`

## What would be needed later

To re-enable complete packaged releases in GitHub Actions, the build would need
private access to:

* a licensed `yFiles` distribution for the Java GUI
* any optional private SDK inputs required for closed-source integrations

Until those inputs exist, release packaging is intentionally left disabled so
the public repository does not advertise a workflow that cannot complete.
