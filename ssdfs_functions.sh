#!/bin/bash

# SSDFS_* vars that should be set:
#
# SSDFS_LIVE - base path for live view
# SSDFS_PENDING - base path for pending view
# SSDFS_BASE - base path on top of live/pending base
#
# SSDFS_S_REAL_BASE - storage real mount path base
# SSDFS_S_LINK_BASE - storage link path base on top of SSDFS_BASE
#
# SSDFS_V_REAL_BASE - volume base path on top of storage real base path
# SSDFS_V_LINK_BASE - volume symlink path base on top of SSDFS_BASE


export SSDFS_V_REAL_BASE SSDFS_V_LINK_BASE

. $SSDFS_VARS

function ssdfs_base {
	if [ "$1" = 'pending' ]; then
		echo -n "$SSDFS_PENDING/$SSDFS_BASE"
	else
		echo -n "$SSDFS_LIVE/$SSDFS_BASE"
	fi
}

# pretty print usage for a given storage name
function ssdfs_storage_usage {
	realpath=`ssdfs_storage_realpath_from_name $1 $2`
	ls $realpath >/dev/null 2>&1 
	df -h | grep $realpath | awk '{ print "size=" $1, "used=" $2, "avail=" $3, $4 }'
}

# return the realpath for a given storage name
function ssdfs_storage_realpath_from_name {
	readlink `ssdfs_base $2`/$SSDFS_S_LINK_BASE/$1
}

# return name of server given storage name
function ssdfs_storage_server_from_name {
	echo `ssdfs_storage_realpath_from_name $1 $2` | sed -e "s|$SSDFS_S_REAL_BASE/||;s|/$1||"
}

# return list of storage names on a given server
function ssdfs_storage_list_storage_on_server {
	for server in `ls -1 $SSDFS_S_REAL_BASE | grep "^$1"` ; do
		echo = $server =
		ls -1 $SSDFS_S_REAL_BASE/$server
	done
}

function ssdfs_create_vol {
	uuid=`uuidgen`
}
