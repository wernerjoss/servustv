#!/bin/bash
#   Install all Packages from Listfile ($1)

Listfile=$1
if [ -f $Listfile ]; then
    while IFS= read -r pkg
    do
        echo "installing $pkg"
        sudo apt-get -y install $pkg
    done < "$Listfile"
else
    echo "$Listfile not found, abort"
fi
