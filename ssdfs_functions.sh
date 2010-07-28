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

# Set SSDFS_VARS to the location of a shell script to set all of the above variables at once
. $SSDFS_VARS

SSDFS_VOLINFO_LIST='name description createdBy createdOn volumeSize diskUsage'

# return the base directory of the filesystem
# args: [pending]
function ssdfs_base {
	pending=$1

	if [ "$pending" = 'pending' ]; then
		echo -n "$SSDFS_PENDING/$SSDFS_BASE"
	else
		echo -n "$SSDFS_LIVE/$SSDFS_BASE"
	fi
}

##
## Storage operations
##

# pretty print usage for a given storage name
# args: <storage> [pending]
function ssdfs_storage_usage {
	storage=$1
	pending=$2

	realpath=$(ssdfs_storage_realpath_from_name $storage $pending)
	ls $realpath >/dev/null 2>&1 
	df -h | grep $realpath 2>&1 | awk '{ print "size=" $1, "used=" $2, "avail=" $3, $4 }'
}

# return the realpath for a given storage name
# args: <storage> [pending]
function ssdfs_storage_realpath_from_name {
	storage=$1
	pending=$2
	
	readlink $(ssdfs_base $pending)/.ssdfs/storage/$storage
}

# return name of server given storage name
# args: <storage> [pending]
function ssdfs_storage_server_from_name {
	storage=$1
	pending=$2

	echo $(ssdfs_storage_realpath_from_name $storage $pending) | sed -e "s|$SSDFS_S_REAL_BASE/||;s|/$storage||"
}

# return list of storage names on a given server
# args: <server full or partial hostname>
function ssdfs_storage_list_storage_by_server {
	server=$1

	for s in $(ls -1 $SSDFS_S_REAL_BASE | grep "^$server") ; do
		echo = $s =
		ls -1 $SSDFS_S_REAL_BASE/$s
	done
}

# return list of all storage
# args: [pending]
function ssdfs_storage_list {
	pending=$1

	for storage in $(ls $(ssdfs_base $pending)/.ssdfs/storage -1) ; do
		echo $storage
	done
}

# return list of volumes by uuid on a given store
# args: <store>
function ssdfs_storage_list_vol_by_uuid {
	store=$1

	realpath=$(ssdfs_storage_realpath_from_name $store)
	ls -1 $realpath/vol/
}

# return list of volumes by name on a given store
# args: <store>
function ssdfs_storage_list_vol_by_name {
	store=$1

	for uuid in $(ssdfs_storage_list_vol_by_uuid $store) ; do
		ssdfs_vol_get_info_by_uuid $uuid name
	done
		
}


##
## Volume operations
##

# return the would-be virtual path to a volume based on uuid
# args: <uuid> [pending]
function ssdfs_vol_linkpath_from_uuid {
	uuid=$1
	pending=$2

	echo $(ssdfs_base $pending)/.ssdfs/vol/by-uuid/$uuid
}

# return the would-be virtual path to a volume based on name. can also accept globs as <name>
# args: <name> [pending]
function ssdfs_vol_linkpath_from_name {
	name=$1
	pending=$2

	echo $(ssdfs_base $pending)/.ssdfs/vol/by-name/$name
}

# return the realpath to a volume based on name. can also accept globs as <name>
# args: <name> [pending]
function ssdfs_vol_realpath_from_name {
	name=$1
	pending=$2

	linkpath=$(ssdfs_vol_linkpath_from_name $name $pending)
	if [ -e "$linkpath" ] ; then
		readlink -f $linkpath 2>/dev/null
	fi
}

# return the realpath to a volume based on uuid
# args: <uuid> [pending]
function ssdfs_vol_realpath_from_uuid {
	uuid=$1
	pending=$2

	linkpath=$(ssdfs_vol_linkpath_from_uuid $uuid $pending)
	if [ -e "$linkpath" ] ; then
		readlink -f $linkpath 2>/dev/null
	fi
}

# return list of volumes by uuid
# args: [pending]
function ssdfs_vol_list_by-uuid {
	pending=$1

	for uuid in $(ls -1 $(ssdfs_base $pending)/.ssdfs/vol/by-uuid/) ; do
		echo $uuid
	done
}

# return list of volume names
# args: [pending]
function ssdfs_vol_list_by-name {
	pending=$1

	for volname in $(ls -1 $(ssdfs_base $pending)/.ssdfs/vol/by-name/) ; do
		echo $volname
	done
}

# get vol info by uuid
# args: <vol uuid> <info> [pending]
function ssdfs_vol_get_info_by_uuid {
	name=$1
	info=$2
	pending=$3

	linkpath=$(ssdfs_vol_linkpath_from_uuid $name $pending)
	if [ -f $linkpath/$info ] ; then
		cat $linkpath/$info
	fi
}

# get vol info by name
# args: <vol name> <info> [pending]
function ssdfs_vol_get_info_by_name {
	name=$1
	info=$2
	pending=$3

	linkpath=$(ssdfs_vol_linkpath_from_name $name $pending)
	if [ -f $linkpath/$info ] ; then
		cat $linkpath/$info
	fi
}

# get uuid from the name, based on the filesystem symlinks
# args: <vol name> [pending]
function ssdfs_vol_get_uuid_from_name {
	name=$1
	pending=$2

	linkpath=$(ssdfs_vol_linkpath_from_name $name $pending)
	uuid=$(basename $(readlink $linkpath 2>/dev/null))
	echo $uuid
}

# rename volume by name
# args: <old vol name> <new vol name>
function ssdfs_vol_rename_by_name {
	oldname=$1
	newname=$2

	if [ -e "$(ssdfs_vol_linkpath_from_name $newname pending)" ] ; then
		echo "Volume with name $newname already exists."
	else
		uuid=$(ssdfs_vol_get_uuid_from_name $oldname pending)
		ssdfs_vol_rename_by_uuid $uuid $newname
	fi
}

# rename volume by uuid
# args: <old vol uuid> <new vol name>
function ssdfs_vol_rename_by_uuid {
	uuid=$1
	newname=$2

	if [ -e "$(ssdfs_vol_linkpath_from_name $newname pending)" ] ; then
		echo "Volume with name $newname already exists."
	else
		linkpath=$(ssdfs_vol_linkpath_from_uuid $uuid pending)
		echo $newname $linkpath/name
		ssdfs_update_by-name
	fi
}

# display all info for a given volume by uuid
# args: <vol uuid> [pending]
function ssdfs_vol_exam_uuid {
	uuid=$1
	pending=$2

	echo uuid = $uuid
	for info in $SSDFS_VOLINFO_LIST ; do
		echo $info = $(ssdfs_vol_get_info_by_uuid $uuid $info $pending)
	done
}

# display all info for a given volume by name
# args: <vol name> [pending]
function ssdfs_vol_exam_name {
	name=$1
	pending=$2

	uuid=$(ssdfs_vol_get_uuid_from_name $name $pending)
	ssdfs_vol_exam_uuid $uuid $pending
}

# create new volume
# args: <storage> <vol name> <vol desc>
function ssdfs_vol_create {
	storage=$1
	name=$2
	description=$3
	
	uuid=$(uuidgen)
	createdBy="$USER"
	createdOn=$(date +%s)

	if [ -e "$(ssdfs_vol_linkpath_from_name $name pending)" ] ; then
		echo "Volume \"$name\" already exists."
		return 0
	fi
	
	if [ -e "$(ssdfs_storage_realpath_from_name $storage)" ] ; then
		realpath="$(ssdfs_storage_realpath_from_name $storage)/vol/$uuid"
		echo "Creating volume on realpath $realpath"
		mkdir -p $realpath
		if [ $? -eq 0 ] ; then
			for info in $SSDFS_VOLINFO_LIST ; do
				touch $realpath/$info
			done
			echo $name > $realpath/name
			echo $description > $realpath/description
			echo $createdBy > $realpath/createdBy
			echo $createdOn > $realpath/createdOn
			echo New volume $name = $uuid
			ssdfs_update_by-uuid && ssdfs_update_by-name && return 1
		else
			echo "Failed to create volume $name [$uuid]."
			return 0
		fi
	else
		echo "$storage does not exist or is unknown to SSDFS."
		exit 1
	fi

}

# destroy volume by name, calls the destroy_by-uuid function after looking up uuid by name
# args: <vol name> [uuid]
function ssdfs_vol_destroy_by-name {
	name=$1

	if [ -e "$(ssdfs_vol_linkpath_from_name $name pending)" ] ; then
		uuid=$(ssdfs_vol_get_uuid_from_name $name pending)
		echo "Mapped volume $name to $uuid"
		if [ $(ls -1 $(ssdfs_vol_linkpath_from_name $name.CONFLICT.* pending) 2>/dev/null | wc -l) -gt 1 ] ; then
			echo "There are also conflicting volumes by that name:"
			for linkpath in $(ssdfs_vol_linkpath_from_name ${name}.CONFLICT.\* pending) ; do
				v=$(basename $linkpath)
				echo $(ssdfs_vol_get_uuid_from_name $v pending) = $v
			done
			echo 
			echo "You must delete the volume by UUID or delete or rename the CONFLICT volumes first."
		else
			ssdfs_vol_destroy_by-uuid $uuid
		fi
	else
		echo "No volume by that name: $name"
	fi
}

# destroy volume by uuid
# args: <vol uuid>
function ssdfs_vol_destroy_by-uuid {
	uuid=$1

	realpath=$(ssdfs_vol_realpath_from_uuid $uuid pending)
	echo About to destroy this volume:
	ssdfs_vol_exam_uuid $uuid pending
	echo -en "Continue? y/[n]  "
	read answer
	if [ "$answer" = "y" ] ; then
		rm -rf $realpath && ssdfs_update_by-uuid && ssdfs_update_by-name
	else
		echo rm -rf $realpath
	fi
}

# split a directory out into a separate volume
# args: <path> <new volume name> <vol description>
function ssdfs_vol_split {
	path=$1
	newvolname=$2
	description=$3

	whereis=$(ssdfs_fs_whereis $path)

	storage=$(echo $whereis | cut -f2 -d' ')
	realpath=$(echo $whereis | cut -f4 -d' ')
	toppath=$(echo $whereis | cut -f5 -d' ')

	if [ "$realpath" != '/' ] ; then
		echo "$path -> $realpath is not part of SSDFS, so you must move/split manually"
	else
		ssdfs_vol_create $storage $newvolname "$description"
		contentpath="$(ssdfs_vol_realpath_from_name $newvolname pending)/content"
		echo contentpath = $contentpath
	fi
}


##
## update_* functions
##

# update the .ssdfs/vol/by-name/ symlink directory
# args:
function ssdfs_update_by-name {
	echo "Updating volume by-name links..."
	rm -f $(ssdfs_base pending)/.ssdfs/vol/by-name/*
	for uuid in $(ssdfs_vol_list_by-uuid pending) ; do
		volname=$(ssdfs_vol_get_info_by_uuid $uuid name pending)
		# check for conflicts
		if [ -L "$(ssdfs_base pending)/.ssdfs/vol/by-name/$volname" ] ; then
			let i=1
			while [ 1 ] ; do
				if [ -e "$(ssdfs_base pending)/.ssdfs/vol/by-name/$volname.CONFLICT.$i" ] ; then
					let i=$i+1
				else
					ln -sf ../by-uuid/$uuid \
						$(ssdfs_base pending)/.ssdfs/vol/by-name/$volname.CONFLICT.$i
					echo "CONFLICT: $uuid/$volname linked as $volname.CONFLICT.$i"
					break
				fi
			done
		else
			ln -sf ../by-uuid/$uuid $(ssdfs_base pending)/.ssdfs/vol/by-name/$volname
		fi
	done
}

# update .ssdfs/vol/by-uuid/ symlink directory
# args:
function ssdfs_update_by-uuid {
	echo "Updating volume by-uuid links..."
	rm -f $(ssdfs_base pending)/.ssdfs/vol/by-uuid/* 2>/dev/null
	for storage in $(ssdfs_storage_list pending) ; do
		for uuid in $(ls -1 $(ssdfs_base pending)/.ssdfs/storage/$storage/vol/ 2>/dev/null) ; do
			ln -sf ../../storage/$storage/vol/$uuid $(ssdfs_base pending)/.ssdfs/vol/by-uuid/$uuid
		done
	done
}


##
## mountpoints
##

# create a mountpoint
# args: <mountpoint name> <vol name>
function ssdfs_mount_create {
	target=$1
	volname=$2

	if [ -e $target ] ; then
		echo $target already exists
		exit 0
	else
		if [ -L "$(ssdfs_vol_linkpath_from_name $volname)" ] ; then
			ln -sf $(ssdfs_vol_linkpath_from_name $volname)/content $target
		else 
			echo "Unkown volume name: $volname"
		fi
	fi
}

# output volume name for a given mount point
# args: <mountpoint list>
function ssdfs_mount_ls {
	mountpoints=$@

	for mount in $mountpoints ; do
		link=$(readlink -f $mount 2>/dev/null)
		if [ "$(basename $link 2>/dev/null)" = 'content' ] ; then
			echo $mount = $(basename $(dirname $link))
		fi
	done
}

##
## filesystem operations
##

# walks a path up to the symlink pointing to somewhere under SSDFS_S_REAL_BASE
# args: <path>
# output: <realpath> <relative path> <linkpath>
function ssdfs_fs_expand {
	input=$1

	# I don't like doing regexes in bash
	if [[ ! "$input" =~ '^/.+' ]] ; then
		input="$(pwd)/$input"
	fi
	
	toppath=''
	test=$input

	while [ -z "$(echo $test | egrep "^$SSDFS_S_REAL_BASE\/.+")" ] && [ "$test" != '/' ] ; do 
		if [ -L "$test" ] ; then 
			linkpath=$test
			test=$(readlink -f $test)
		else 
			toppath="/$(basename $test)$toppath"
			test=$(dirname $test)
		fi
	done

	echo "$test $toppath $linkpath"
}

# give verbose information about where a given file/directory is
# args: <path>
# output: <server> <storage> <linkpath> <realpath> <toppath>
function ssdfs_fs_whereis {
	path=$1

	# ugh, this is hideous
	expansion=$(ssdfs_fs_expand $path)
	realpath=$(echo $expansion | cut -f 1 -d' ')
	toppath=$(echo $expansion | cut -f 2 -d' ')
	linkpath=$(echo $expansion | cut -f 3 -d ' ')

	realpath2=$(echo $realpath | sed -e "s|$SSDFS_S_REAL_BASE/||")
	server=$(echo $realpath2 | cut -f1 -d/)
	storage=$(echo $realpath2 | cut -f2 -d/)
	#realpath=$(echo $realpath2 | cut -f3- -d/)

	echo "$server $storage $linkpath $realpath $toppath"
}

