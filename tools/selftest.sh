#!/bin/zsh
# Runs the in-app self-test on fixture output (never the real Mole). Exit code 0 when every check passed.
set -u
here=${0:A:h:h}
rm -rf ~/Library/Saved\ Application\ State/com.maz.burrow.savedState
APP_FIXTURES=$here/Tests/Fixtures ~/Applications/Burrow.app/Contents/MacOS/Burrow --selftest
