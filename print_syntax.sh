#!/bin/bash
file=$1

egrep -A 3 "^# args" $file  \
 | egrep "(args:|function)" \
 | sed -re 'N;s/^# args: *(\S*)/\1/;s/\n/ /;s/function//;s/\{//' \
 | awk '
  { printf("%s ",$NF) } 
  {
	  if (NF != 1) { 
		  for (i=1; i<NF; i++) { 
			  printf("%s ", $i) 
		  } 
	  } 
	print " " 
  }'
