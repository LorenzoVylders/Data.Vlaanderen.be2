#!/bin/bash

#set -x 

# Arg1 = file under consideration
# Arg2 = data to be created
# Arg3 = json values selector to extract the data from file Arg1 to be aggregated in file Arg2
filedir=$(dirname $1)
ROOTSPECIFICATIONS=$(cat rootspecifications)

for root in ${ROOTSPECIFICATIONS} ;
do
if [[ "${filedir}" =~ "${root}" ]] ; then
        echo "found"
  jq -s ".[0] + .[1].values.$3  " $2 "$1" >> $2.0 ;
  mv $2.0 $2;
fi
done

