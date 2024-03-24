#!/bin/bash
# convert m3u8 Playlist Recording to mp4 (or just move/rename mp4)
# mp4 Basename is derived from $WorkDir/archiv/racelist.csv, entry matching current date

# default Parameters:
# WorkDir="$HOME/tmp/video"	# for local test
WorkDir="/var/www/html/video"
# playlist="sprint.m3u8"
playlist="sprint.mp4"
plsbase=`echo $playlist | awk -F \. '{print $1}'`
# verbose=1

while getopts ":w:f:" opt; do
	case $opt in 
	w)
		WorkDir=$OPTARG
		;;
	f)
		playlist=$OPTARG
		;;
	\?)
		echo "Invalid option: -$OPTARG" >&2
		exit 1
		;;
	:)
		echo "Option -$OPTARG requires an argument." >&2
		exit 1
		;;
	esac
done

playlist=$WorkDir/$playlist	# new	27.2.
plsbase=`echo $playlist | awk -F \. '{print $1}'`
plsbase=$(basename "${plsbase}")
type=`echo $playlist | awk -F \. '{print $2}'`
OutDir=$WorkDir/archiv/	# should be absolute PATH for call via at or cron
OutFile=$OutDir$plsbase.mp4	# should be absolute PATH for call via at or cron

if [ ! -d "$OutDir" ];then
	echo "Directory $OutDir does not exist, abort"
	exit
fi

if ([ "$plsbase" == "sprint" ] || [ "$plsbase" == "race" ]);then
	echo "plsbase $plsbase ok, trying to find entry in racelist"
	curdir=`pwd`	# get current dir
	echo "$WorkDir $curdir"
	if [ "$curdir" != "$WorkDir" ];then	# switch to WorkDir, if not yet there
		if [ ! -z $verbose ];then
			echo "pushd $WorkDir"
		else
			pushd $WorkDir
		fi
	fi

	if [ -f $OutDir/racelist.csv ];then	# build OutFile Name from racelist.csv Entry that matches current date
		awk -F \; '{printf "%s-%s\n",$2,$1}' $OutDir/racelist.csv > $OutDir/racelist.lst
		curdate=`date +"%Y-%m-%d"`
		event=`grep $curdate $OutDir/racelist.lst`	# racelist.lst must be found in WorkDir
		if [ ! -z $event ];then
			OutFile="$OutDir$event.mp4"
		else
			echo "no matching Entry in Racelist found, nothing converted !" | tee /home/josswern/mp4toarchiv.log
			popd
			exit
		fi
	else
		echo "no Racelist File found, nothing converted !" | tee /home/josswern/mp4toarchiv.log
		popd
		exit
	fi

	if [ ! -z $verbose ];then
		echo $WorkDir
		echo $playlist
		echo $plsbase
		echo $curdate
		echo $event
		echo $OutFile
		if [ "$type" = "m3u8" ];then
			echo "ffmpeg -i $playlist -codec copy $OutFile"
		else
			echo "rsync $playlist $OutFile"
		fi
		echo "Simulation, nothing done :-)"
		popd
		exit
	fi
	if [ -f $playlist ];then
		if [ "$type" = "m3u8" ];then
			ffmpeg -i $playlist -codec copy $OutFile
			rm "$plsbase"*".m3u8"	# remove Playlist
			rm "$plsbase"*".ts"	# remove .ts video snippets
		else
			# rsync -t $playlist $OutFile
			mv $playlist $OutFile	# move to archiv folder, with appr. name
			# rm $playlist
			# ln -s $OutFile $playlist	# link archived video to WorkDir	-	obsolete, wil not work anyway
			# rm "$plsbase"?".mp4"	# remove mp4 chunks, should already be done by cropvideo.sh
		fi
	else
		echo "$playlist not found, nothing converted !"
		popd
		exit	# stop here
	fi
	# update (expand) archiv.inc.php for Include in index.php
	echo "<a href='archiv/$event.mp4'>$event.mp4</a></br>" >> $WorkDir/archiv.inc.php
	# rewrite vid.inc.php (Symlinks won't work here !)
	echo "<video controls style='max-width: 960px;'>" > $WorkDir/vid.inc.php
	echo "<source src='archiv/$event.mp4' type='video/mp4'>" >> $WorkDir/vid.inc.php
	echo "</video>" >> $WorkDir/vid.inc.php
	if [ "$curdir" != "$WorkDir" ];then
		popd
	fi
else
	echo "plsbase $plsbase not valid for archiving, stop"
fi

