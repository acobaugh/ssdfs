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
	local pending=$1

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
	local storage=$1
	local pending=$2

	local realpath=$(ssdfs_storage_realpath_from_name $storage $pending)
	ls $realpath >/dev/null 2>&1 
	df -h | grep $realpath 2>&1 | awk '{ print "size=" $1, "used=" $2, "avail=" $3, $4 }'
}

# return the realpath for a given storage name
# args: <storage> [pending]
function ssdfs_storage_realpath_from_name {
	local storage=$1
	local pending=$2
	
	readlink $(ssdfs_base $pending)/.ssdfs/storage/$storage
}

# return name of server given storage name
# args: <storage> [pending]
function ssdfs_storage_server_from_name {
	local storage=$1
	local pending=$2

	echo $(ssdfs_storage_realpath_from_name $storage $pending) | sed -e "s|$SSDFS_S_REAL_BASE/||;s|/$storage||"
}

# return list of storage names on a given server
# args: <server full or partial hostname>
function ssdfs_storage_list_storage_by_server {
	local server=$1

	for s in $(ls -1 $SSDFS_S_REAL_BASE | grep "^$server") ; do
		echo = $s =
		ls -1 $SSDFS_S_REAL_BASE/$s
	done
}

# return list of all storage
# args: [pending]
function ssdfs_storage_list {
	local pending=$1

	for storage in $(ls $(ssdfs_base $pending)/.ssdfs/storage -1) ; do
		echo $storage
	done
}

# return list of volumes by uuid on a given store
# args: <store>
function ssdfs_storage_list_vol_by_uuid {
	local store=$1

	local realpath=$(ssdfs_storage_realpath_from_name $store)
	ls -1 $realpath/vol/
}

# return list of volumes by name on a given store
# args: <store>
function ssdfs_storage_list_vol_by_name {
	local store=$1

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
	local uuid=$1
	local pending=$2

	echo $(ssdfs_base $pending)/.ssdfs/vol/by-uuid/$uuid
}

# return the would-be virtual path to a volume based on name. can also accept globs as <name>
# args: <name> [pending]
function ssdfs_vol_linkpath_from_name {
	local name=$1
	local pending=$2

	echo $(ssdfs_base $pending)/.ssdfs/vol/by-name/$name
}

# return the realpath to a volume based on name. can also accept globs as <name>
# args: <name> [pending]
function ssdfs_vol_realpath_from_name {
	local name=$1
	local pending=$2

	local linkpath=$(ssdfs_vol_linkpath_from_name $name $pending)
	if [ -e "$linkpath" ] ; then
		readlink -f $linkpath 2>/dev/null
	fi
}

# return the realpath to a volume based on uuid
# args: <uuid> [pending]
function ssdfs_vol_realpath_from_uuid {
	local uuid=$1
	local pending=$2

	local linkpath=$(ssdfs_vol_linkpath_from_uuid $uuid $pending)
	if [ -e "$linkpath" ] ; then
		readlink -f $linkpath 2>/dev/null
	fi
}

# return list of volumes by uuid
# args: [pending]
function ssdfs_vol_list_by-uuid {
	local pending=$1

	for uuid in $(ls -1 $(ssdfs_base $pending)/.ssdfs/vol/by-uuid/) ; do
		echo $uuid
	done
}

# return list of volume names
# args: [pending]
function ssdfs_vol_list_by-name {
	local pending=$1

	for volname in $(ls -1 $(ssdfs_base $pending)/.ssdfs/vol/by-name/) ; do
		echo $volname
	done
}

# get vol info by uuid
# args: <vol uuid> <info> [pending]
function ssdfs_vol_get_info_by_uuid {
	local name=$1
	local info=$2
	local pending=$3

	local linkpath=$(ssdfs_vol_linkpath_from_uuid $name $pending)
	if [ -f $linkpath/$info ] ; then
		cat $linkpath/$info
	fi
}

# get vol info by name
# args: <vol name> <info> [pending]
function ssdfs_vol_get_info_by_name {
	local name=$1
	local info=$2
	local pending=$3

	local linkpath=$(ssdfs_vol_linkpath_from_name $name $pending)
	if [ -f $linkpath/$info ] ; then
		cat $linkpath/$info
	fi
}

# get uuid from the name, based on the filesystem symlinks
# args: <vol name> [pending]
function ssdfs_vol_get_uuid_from_name {
	local name=$1
	local pending=$2

	local linkpath=$(ssdfs_vol_linkpath_from_name $name $pending)
	local uuid=$(basename $(readlink $linkpath 2>/dev/null))
	echo $uuid
}

# rename volume by name
# args: <old vol name> <new vol name>
function ssdfs_vol_rename_by_name {
	local oldname=$1
	local newname=$2

	if [ -e "$(ssdfs_vol_linkpath_from_name $newname pending)" ] ; then
		echo "Volume with name $newname already exists."
	else
		local uuid=$(ssdfs_vol_get_uuid_from_name $oldname pending)
		ssdfs_vol_rename_by_uuid $uuid $newname
	fi
}

# rename volume by uuid
# args: <old vol uuid> <new vol name>
function ssdfs_vol_rename_by_uuid {
	local uuid=$1
	local newname=$2

	if [ -e "$(ssdfs_vol_linkpath_from_name $newname pending)" ] ; then
		echo "Volume with name $newname already exists."
	else
		local linkpath=$(ssdfs_vol_linkpath_from_uuid $uuid pending)
		echo $linkpath
		echo $newname > $linkpath/name
		ssdfs_update_by-name
	fi
}

# display all info for a given volume by uuid
# args: <vol uuid> [pending]
function ssdfs_vol_exam_uuid {
	local uuid=$1
	local pending=$2

	echo uuid = $uuid
	for info in $SSDFS_VOLINFO_LIST ; do
		echo $info = $(ssdfs_vol_get_info_by_uuid $uuid $info $pending)
	done
}

# display all info for a given volume by name
# args: <vol name> [pending]
function ssdfs_vol_exam_name {
	local name=$1
	local pending=$2

	local uuid=$(ssdfs_vol_get_uuid_from_name $name $pending)
	ssdfs_vol_exam_uuid $uuid $pending
}

# create new volume
# args: <storage> <vol name> <vol desc>
function ssdfs_vol_create {
	local storage=$1
	local name=$2
	local description=$3
	
	local uuid=$(uuidgen)
	local createdBy="$USER"
	local createdOn=$(date +%s)

	if [ -e "$(ssdfs_vol_linkpath_from_name $name pending)" ] ; then
		echo "Volume \"$name\" already exists."
	fi
	
	if [ -e "$(ssdfs_storage_realpath_from_name $storage)" ] ; then
		local realpath="$(ssdfs_storage_realpath_from_name $storage)/vol/$uuid"
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
			mkdir $realpath/content
			echo New volume $name = $uuid
			ssdfs_update_by-uuid 
			ssdfs_update_by-name
		else
			echo "Failed to create volume $name [$uuid]."
		fi
	else
		echo "$storage does not exist or is unknown to SSDFS."
	fi

}

# destroy volume by name, calls the destroy_by-uuid function after looking up uuid by name
# args: <vol name> [uuid]
function ssdfs_vol_destroy_by-name {
	local name=$1

	if [ -e "$(ssdfs_vol_linkpath_from_name $name pending)" ] ; then
		local uuid=$(ssdfs_vol_get_uuid_from_name $name pending)
		echo "Mapped volume $name to $uuid"
		if [ $(ls -1 $(ssdfs_vol_linkpath_from_name $name.CONFLICT.* pending) 2>/dev/null | wc -l) -gt 1 ] ; then
			echo "There are also conflicting volumes by that name:"
			for linkpath in $(ssdfs_vol_linkpath_from_name ${name}.CONFLICT.\* pending) ; do
				local v=$(basename $linkpath)
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
	local uuid=$1

	local realpath=$(ssdfs_vol_realpath_from_uuid $uuid pending)
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
	local path=$1
	local newvolname=$2
	local description=$3

	if [ -e "$(ssdfs_vol_linkpath_from_name $newvolname pending)" ] ; then
		echo "Volume with name $newvolname already exists."
	else
		echo "Attempting to determine real location of $path"
		local whereis=$(ssdfs_fs_whereis $path)

		local storage=$(echo $whereis | cut -f2 -d,)
		local realpath=$(echo $whereis | cut -f4 -d,)
		local toppath=$(echo $whereis | cut -f5 -d,)

		if [ "$realpath" = '/' ] || [ -z "$realpath" ] ; then
			echo "$path -> $realpath is not part of SSDFS, so you must move/split manually"
		else
			echo "Mapped $path -> $realpath $toppath"
			echo "...stored on $storage"
			ssdfs_vol_create $storage $newvolname "$description"
			local contentpath="$(ssdfs_vol_realpath_from_name $newvolname pending)/content"
			# double-check that everything is good
			if [ -d $contentpath ] ; then
				rmdir $contentpath
				echo "About to move $path to $contentpath"
				echo "Please verify that we mapped the input path to the correct realpath,"
				echo "and that we will be moving the input path to some other location on the same server/storage,"
				echo "otherwise the 'mv' could take a very very long time."
				echo -en "Continue? y/[n] "
				read answer
				if [ "$answer" = "y" ] ; then
					mv ${realpath}${toppath} $contentpath
				else
					echo mv ${realpath}${toppath} $contentpath
				fi
			fi
		fi
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
		local volname=$(ssdfs_vol_get_info_by_uuid $uuid name pending)
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
	local target=$1
	local volname=$2

	if [ -e $target ] ; then
		echo $target already exists
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
	local mountpoints=$@

	for mount in $mountpoints ; do
		local link=$(readlink -f $mount 2>/dev/null)
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
	local input=$1

	# I don't like doing regexes in bash
	if [[ ! "$input" =~ '^/.+' ]] ; then
		input="$(pwd)/$input"
	fi
	
	local toppath=''
	local linkpath=''
	local test=$(readlink -f $input)

	while [ -z "$(echo $test | egrep "^$SSDFS_S_REAL_BASE\/.+")" ] && [ "$test" != '/' ] ; do 
		if [ -L "$test" ] ; then 
			linkpath=$test
			test=$(readlink -f $test)
		else 
			toppath="/$(basename $test)$toppath"
			test=$(dirname $test)
		fi
	done

	echo "$test,$toppath,$linkpath"
}

# give verbose information about where a given file/directory is
# args: <path>
# output: <server> <storage> <linkpath> <realpath> <toppath>
function ssdfs_fs_whereis {
	local path=$1

	# ugh, this is hideous
	local expansion=$(ssdfs_fs_expand $path)
	local realpath=$(echo $expansion | cut -f 1 -d,)
	local toppath=$(echo $expansion | cut -f 2 -d,)
	local linkpath=$(echo $expansion | cut -f 3 -d,)

	local realpath2=$(echo $realpath | sed -e "s|$SSDFS_S_REAL_BASE/||")
	local server=$(echo $realpath2 | cut -f1 -d/)
	local storage=$(echo $realpath2 | cut -f2 -d/)
	#realpath=$(echo $realpath2 | cut -f3- -d/)

	echo "$server,$storage,$linkpath,$realpath,$toppath"
}

