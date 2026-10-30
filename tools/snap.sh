#!/bin/zsh
# Snapshots of every page and state in light and dark, from fixture output (never the real Mole).
# Usage: tools/snap.sh            all shots
#        APP_SNAPSHOT_PAGES=01-health,settings tools/snap.sh
set -u
here=${0:A:h:h}
app=~/Applications/Burrow.app/Contents/MacOS/Burrow
shots=/tmp/Burrow-shots
# A crashed run leaves saved window state, and the next launch would wait on a "reopen windows?" alert.
rm -rf ~/Library/Saved\ Application\ State/com.maz.burrow.savedState
rm -rf $shots
APP_FIXTURES=$here/Tests/Fixtures APP_SNAPSHOT=$shots $app
