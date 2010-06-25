#!/bin/bash

. $SSDFS_VARS

function ssdfs_base {
	if [ "$1" = 'pending' ]; then
		echo -n "$PENDING/$BASE"
	else
		echo -n "$LIVE/$BASE"
	fi
}

function ssdfs_list_storage {
	ls -al `base $1`
}
