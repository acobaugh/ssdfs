#!/bin/bash

## 
## updates diskUsage and volumeSize given a list of storage paths
## this requires du from GNU coreutils. --apparent-size is useful
## if the underlying storage uses compression (like ZFS)
##
## args: <list of full paths to storage>
## output: none
##
for storage in $@ ; do
	for uuid in `ls -1 $storage/vol/` ; do
		du -ks $storage/vol/$uuid/content | cut -f1 > $storage/vol/$uuid/diskUsage
		du -ks --apparent-size $storage/vol/$uuid/content | cut -f1 > $storage/vol/$uuid/volumeSize
	done
done
