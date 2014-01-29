eyetvmacsync
============

Scripts to copy and sync eyetv shows recorded on a server to a client machine

You should be able to reverse-enginner how to set it up based on the
command-line parameters in the main script...basically I run it like this:

~/bin/eyetvsync.pl --transfer-log ~/var/eyetvsync.log --local-shows-dir ~/Documents/EyeTV\ Archive/ --remote-shows-dir "/Volumes/STX3TB/EyeTV Archive" --remote-host eyetv-server.local --remote-user username --patterns-file ~/etc/eyetv-patterns.txt --local-staging-dir /Users/username/EyeTvStaging/ --debug

I have it auto-starting by installing a compiled AppleScript (included) and
having it run as a login item.  There are several other ways of getting it
to start on Mac OS X, pick your poison!
