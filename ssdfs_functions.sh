#!/bin/bash

# SSDFS_* vars that should be set:
#
# SSDFS_LIVE - base path for live view
# SSDFS_PENDING - base path for pending view
# SSDFS_BASE - base path on top of live/pending base
#
# SSDFS_S_REAL_BASE - storage real mount path base
#
# SSDFS_V_REAL_BASE - volume base path on top of storage real base path


#export SSDFS_V_REAL_BASE SSDFS_V_LINK_BASE

. $SSDFS_VARS

SSDFS_VOLINFO_LIST='name description createdBy createdOn volumeSize diskUsage'

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
	df -h | grep $realpath 2>&1 | awk '{ print "size=" $1, "used=" $2, "avail=" $3, $4 }'
}

# return the realpath for a given storage name
function ssdfs_storage_realpath_from_name {
	readlink `ssdfs_base $2`/.ssdfs/storage/$1
}

# return name of server given storage name
function ssdfs_storage_server_from_name {
	echo `ssdfs_storage_realpath_from_name $1 $2` | sed -e "s|$SSDFS_S_REAL_BASE/||;s|/$1||"
}

# return list of storage names on a given server
function ssdfs_storage_list_storage_on_server {
	for server in $(ls -1 $SSDFS_S_REAL_BASE | grep "^$1") ; do
		echo = $server =
		ls -1 $SSDFS_S_REAL_BASE/$server
	done
}

# return list of all storage
function ssdfs_storage_list {
	for storage in $(ls `ssdfs_base $1`/.ssdfs/storage -1) ; do
		echo $storage
	done
}

# return list of 
function ssdfs_vol_create {
	uuid=`uuidgen`
	storage=$1
	name=$2
	description=$3
	createdBy=

}

function ssdfs_vol_fullpath_from_uuid {
	echo `ssdfs_base $2`/.ssdfs/vol/by-uuid/$1
}

function ssdfs_vol_fullpath_from_name {
	echo `ssdfs_base $2`/.ssdfs/vol/by-name/$1
}

function ssdfs_vol_list_by-uuid {
	for uuid in $(ls -1 `ssdfs_base $1`/.ssdfs/vol/by-uuid/) ; do
		echo $uuid
	done
}

function ssdfs_vol_list_by-name {
	for volname in $(ls -1 `ssdfs_base $1`/.ssdfs/vol/by-name/) ; do
		echo $volname
	done
}

function ssdfs_vol_get_info_by_uuid {
	fullpath=$(ssdfs_vol_fullpath_from_uuid $1 $3)
	if [ -f $fullpath/$2 ] ; then
		cat $fullpath/$2
	fi
}

function ssdfs_vol_get_info_by_name {
	fullpath=$(ssdfs_vol_fullpath_from_name $1 $3)
	if [ -f $fullpath/$2 ] ; then
		cat $fullpath/$2
	fi
}

function ssdfs_vol_get_uuid_from_name {
	fullpath=$(ssdfs_vol_fullpath_from_name $1 $2)
	uuid=$(basename $(readlink $fullpath 2>/dev/null))
	echo $uuid
}

# update the .ssdfs/vol/by-name/ symlink directory
function ssdfs_update_by-name {
	rm -f `ssdfs_base pending`/.ssdfs/vol/by-name/*
	for uuid in $(ssdfs_vol_list_by-uuid pending) ; do
		volname=$(ssdfs_vol_get_info_by_uuid $uuid name pending)
		# check for conflicts
		if [ -L "`ssdfs_base pending`/.ssdfs/vol/by-name/$volname" ] ; then
			let i=1
			while [ 1 ] ; do
				if [ -L "`ssdfs_base pending`/.ssdfs/vol/by-name/$volname.CONFLICT.$i" ] ; then
					let i=$i+1
				else
					echo ln -sf ../by-uuid/$uuid \
						`ssdfs_base pending`/.ssdfs/vol/by-name/$volname.CONFLICT.$i
					echo "CONFLICT: $uuid/$volname linked as $volname.CONFLICT.$i"
					break
				fi
			done
		else
			ln -sf ../by-uuid/$uuid `ssdfs_base pending`/.ssdfs/vol/by-name/$volname
		fi
	done
}

# update .ssdfs/vol/by-uuid/ symlink directory
function ssdfs_update_by-uuid {
	rm -f `ssdfs_base pending`/.ssdfs/vol/by-uuid/* 2>/dev/null
	for storage in `ssdfs_storage_list pending` ; do
		for uuid in $(ls -1 `ssdfs_base pending`/.ssdfs/storage/$storage/vol/ 2>/dev/null) ; do
			ln -sf ../../storage/$storage/vol/$uuid `ssdfs_base pending`/.ssdfs/vol/by-uuid/$uuid
		done
	done
}

function ssdfs_vol_exam_uuid {
	uuid=$1
	echo $uuid
	for info in $SSDFS_VOLINFO_LIST ; do
		echo $info = `ssdfs_vol_get_info_by_uuid $uuid $info`
	done
}

function ssdfs_vol_exam_name {
	name=$1
	echo $name
	for info in $SSDFS_VOLINFO_LIST ; do
		echo $info = `ssdfs_vol_get_info_by_name $name $info`
	done
}

function ssdfs_mount_create {
	target=$1
	volname=$2
	if [ -e $target ] ; then
		echo $target already exists
		exit 0
	else
		if [ -L "`ssdfs_vol_fullpath_from_name $volname`" ] ; then
			ln -sf `ssdfs_vol_fullpath_from_name $volname`/content $target
		else 
			echo "Unkown volume name: $volname"
		fi
	fi
}

## output volume name for a given mount point
## args: <mountpoint list>
## output: <mountpoint> = <volume name>
function ssdfs_mount_ls {
	for mount in $@ ; do
		link=`readlink $mount 2>/dev/null`
		if [ "`basename $link 2>/dev/null`" = 'content' ] ; then
			echo $mount = $(basename $(dirname $link))
		fi
	done
}

