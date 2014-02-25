#!/bin/bash
##############################################
# Dropbox Updater
##############################################
# Version 20140225
##############################################
# TODO: 32/64 bits autodetect
# TODO: automated install of https://www.dropbox.com/download?dl=packages/dropbox.py
# TODO: Version checking with file .dropbox-dist/VERSION
##############################################

# Go to the home dir
cd $HOME

# DropBox Python script define
DBPY="/usr/local/bin/dropbox"

# Checking if we have the dropbox script
if [[ -e "$DBPY" ]]; then
	HAVE_DPS="yes"
else
	HAVE_DPS="no"
fi

# Stop dropbox
if [[ "$DPS" = "yes" ]]; then
	$DBPY stop
fi
if [[ "$DPS" = "no" ]]; then
	kill -9 $(ps -ef | grep ".dropbox-dist/dropbox" | grep -v grep | awk '{ print $2 }')
fi

# Remove dropbox file directory
rm -rf $HOME/.dropbox-dist

# Download the most current version (assuming 64-bits)
wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -

# Start dropbox again
if [[ "$DPS" = "yes" ]]; then
	$DBPY start
fi
if [[ "$DPS" = "no" ]]; then
	$HOME/.dropbox-dist/dropboxd
fi

# END
###