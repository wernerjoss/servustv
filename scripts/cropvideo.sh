#!/bin/bash
# Usage: cropvideo.sh -f videofile
# reduce video size, cleanup obsolete chunks

# default Parameters:
WorkDir="/var/www/html/video"	# no Trailing Slash !
# WorkDir="$HOME/tmp/video"	# local Test - must NOT be ~/tmp/video !
RecFile="redbull.m3u8"	# just File Name without Path
# dryrun=1
LogFile=/tmp/cropvideo.log

while getopts ":f:" opt; do
	case $opt in 
	f)
		RecFile=$OPTARG	# should be quali.m3u8, sprint.m3u8 oder race.m3u8
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

tsname=$(basename "${RecFile}")
tsbase=$(echo "$tsname" | awk -F . '{print $1}')
type=$(echo "$tsname" | awk -F . '{print $2}')

absRecFile=$WorkDir/$tsbase.$type

if [ ! -f $LogFile ];then
	touch $LogFile
fi

d=$(date)	
logmsg="$d : creating scaled video: $tsbase.mp4"
echo $logmsg | tee -a $LogFile

if [ -f $WorkDir/scaled.mp4 ];then
    rm $WorkDir/scaled.mp4
fi
    
if [ "$type" = "mp4" ];then
	if [ -f $WorkDir/videos.txt ];then
        # ffmpeg -safe 0 -f concat -i $WorkDir/videos.txt -vf scale=1280:-2 $absRecFile
        ffmpeg -i $absRecFile -vf scale=1280:-2 $WorkDir/scaled.mp4
        if [ -f $WorkDir/scaled.mp4 ];then
	        mv -f $WorkDir/scaled.mp4 $WorkDir/$tsbase.mp4
	        logmsg="$d : cleaning up $WorkDir/$tsbase?.mp4"
			echo $logmsg | tee -a $LogFile
		    if [ -f $WorkDir/$tsbase.mp4 ]; then
	            rm $WorkDir/$tsbase?.mp4
	        fi
	    fi
	    rm $WorkDir/videos.txt
    fi
else
	# ffmpeg -i "$absRecFile" -codec copy $WorkDir/scaled.mp4	# convert m3u8 to mp4
	if [ -f $absRecFile ];then
	    ffmpeg -i $absRecFile -vf scale=1280:-2 $WorkDir/scaled.mp4	# convert m3u8 to scaled mp4
		d=$(date)
		logmsg="$d : finished creating scaled video $WorkDir/scaled.mp4"
		echo $logmsg | tee -a $LogFile
		if [ -f $WorkDir/scaled.mp4 ];then
	        mv -f $WorkDir/scaled.mp4 $WorkDir/$tsbase.mp4
	        logmsg="$d : cleaning up $WorkDir/*.ts"
			echo $logmsg | tee -a $LogFile
		    if [ -f $WorkDir/$tsbase.mp4 ]; then
	            rm $WorkDir/*.ts
		        rm $absRecFile
	        fi
	    fi
    fi
fi
