#!/bin/bash
directory="/home/tyhawk/TransFusion/Spanje_2015"

videobestanden=( $( find "$directory" -name '*MOV' -exec basename {} .MOV \; ) )
echo "Array length: ${#videobestanden[@]}"

for bestand in ${videobestanden[@]}
do
    find "$directory" -name "${bestand}.JPG"
done
