#!/bin/bash

. $SSDFS_VARS

function ssdfs_base {
	if [ "$1" = 'pending' ]; then
		echo -n "$SSDFS_PENDING/$SSDFS_BASE"
	else
		echo -n "$SSDFS_LIVE/$SSDFS_BASE"
	fi
}

function ssdfs_list_storage {
	ls -al `ssdfs_base $1`
}
