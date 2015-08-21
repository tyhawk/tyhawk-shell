#!/bin/bash
directory="/home/tyhawk/TransFusion/Spanje_2015"

videobestanden=( $( find "$directory" -name '*MOV' -exec basename {} .MOV \; ) )

for bestand in ${videobestanden[@]}
do
    find "$directory" -name "${bestand}.JPG" -delete
done
