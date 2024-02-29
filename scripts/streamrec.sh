#!/bin/bash
# Usage: streamrec.sh (direct Call) or
# at 06:30 tomorrow -f ~/bin/streamrec.sh	# scheduled call via at

# default Parameters:
UserAgent="Mozilla/5.0_(Windows_NT_10.0_Win64_x64)_AppleWebKit/537.36_(KHTML_like_Gecko)_Chrome/71.0.3554.0_Safari/537.36"
# UserAgent="VLC/3.0.20-0+deb12u1"
# Note: UserAgent may NOT contain Blanks, Semicolons etc. !
StreamUrl="https://stv-live.akamaized.net/hls/live/2031011/lingeoSTVATwebPri/master.m3u8"	# Servus TV AT
# StreamUrl="https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8"       # Red Bull TV
RecTime=300	# Seconds
WorkDir="/var/www/html/video"	# no Trailing Slash !
# WorkDir="$HOME/tmp/video"	# local Test - must NOT be ~/tmp/video !
RecFile="sprint.mp4"	# just File Name without Path
NumParts=2	# #No. of Parts
# verbose=1

while getopts ":u:t:n:f:" opt; do
	case $opt in 
	u)
		StreamUrl=$OPTARG
		;;
	t)
		RecTime=$OPTARG
		;;
	f)
		RecFile=$OPTARG	# should be quali.m3u8, sprint.m3u8 oder race.m3u8
		;;
	n)
		NumParts=$OPTARG	# only relevant for mp4 recording, ignored for m3u8 !
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

tsname=$(basename "${RecFile}")	# now obsolete, but should not matter :-)
tsbase=`echo $tsname | awk -F . '{print $1}'`
type=`echo $tsname | awk -F . '{print $2}'`

if [ "$verbose" ];then
	echo $StreamUrl
	echo $WorkDir
	echo $RecTime
	echo $RecFile
	echo $NumParts
	echo $type
	#	exit
else
	if [ "$type" = "mp4" ];then
		rm $tsbase*.mp4
	else
		rm $RecFile
		rm $tsbase*.ts
	fi
fi

if [ -f "$WorkDir/vid.inc.php" ];then 
	rm $WorkDir/vid.inc.php
fi
touch "$WorkDir/vid.inc.php"   # avoid php warning file not found
	
if [ "$type" = "mp4" ];then
	for (( Num=0; Num<NumParts; Num++ )) ; {
		incRecFile="$tsbase$Num.mp4"
		absRecFile="$WorkDir/$tsbase$Num.mp4"
		if [ -f "$absRecFile" ]; then
			echo "removing $absRecFile"
			rm -f $absRecFile
		fi
		if [ ! -z $verbose ]; then
			echo $absRecFile
			echo "Simulation, nothing recorded :-)"
		else
			# Video Recording goes here
			ffmpeg -n -user_agent $UserAgent -i $StreamUrl -t $RecTime -c copy $absRecFile	# mp4 Recording, reloded :-)
			# display recorded part $Num AFTER record finished
			echo "<video controls style='max-width: 960px;'>" >> $WorkDir/vid.inc.php
			echo "<source src=$incRecFile type='video/mp4'>" >> $WorkDir/vid.inc.php
			echo "</video>" >> $WorkDir/vid.inc.php
        fi
	}
else
	if [ ! -z $verbose ]; then
		echo $RecFile
		echo "Simulation, nothing recorded :-)"
	else
		# display playlist BEFORE record finished
		echo "<video-js" >> $WorkDir/vid.inc.php
		echo "id='my-video'" >> $WorkDir/vid.inc.php
		echo "class='video-js'" >> $WorkDir/vid.inc.php
		echo "controls" >> $WorkDir/vid.inc.php
		echo "preload='auto'" >> $WorkDir/vid.inc.php
		echo "width='960'" >> $WorkDir/vid.inc.php
		echo "data-setup='{\"liveui\": true}'>" >> $WorkDir/vid.inc.php
		# use $tsname in vid.inc.php, NOT $RecFile !
		echo "<source src='$tsname' type='application/x-mpegURL' />" >> $WorkDir/vid.inc.php
		echo "<p class='vjs-no-js'>" >> $WorkDir/vid.inc.php
		echo "To view this video please enable JavaScript, and consider upgrading to a " >> $WorkDir/vid.inc.php
		echo "web browser that" >> $WorkDir/vid.inc.php
		echo "<a href='https://videojs.com/html5-video-support/' target='_blank'>supports HTML5 video</a>" >> $WorkDir/vid.inc.php
		echo "</p>" >> $WorkDir/vid.inc.php
		echo "</video-js>" >> $WorkDir/vid.inc.php
		ffmpeg -n -user_agent $UserAgent -i $StreamUrl -t $RecTime -c:v libx264 -crf 21 -preset veryfast -c:a aac -b:a 128k -ac 2 -f hls -hls_time 4 -hls_playlist_type event $RecFile
	fi
fi

if [ "$verbose" ];then
	echo "exit"
fi
if [ -f "$WorkDir/videos.txt" ];then
	rm $WorkDir/videos.txt
fi
sleep $(($NumParts * $RecTime))       #       sleep total Recording Time before creating final video 28.2.
if [ "$type" = "mp4" ];then
	if [ -f $WorkDir/$tsbase.mp4 ];then 
		rm $WorkDir/$tsbase.mp4	# avoid ffmpeg Error if mp4 File exists
	fi
	for f in $WorkDir/$tsbase*.mp4; do echo "file '$f'" >> $WorkDir/videos.txt; done
	if [ "$verbose" ];then
		echo "command:"
		echo "ffmpeg -safe 0 -f concat -i $WorkDir/videos.txt -c copy $WorkDir/$tsbase.mp4"
		exit
	fi
	ffmpeg -safe 0 -f concat -i $WorkDir/videos.txt -c copy $WorkDir/$tsbase.mp4
	# display final recorded Video $Num AFTER record finished
	echo "<h3>Final Video:</h3>" > $WorkDir/vid.inc.php	# 28.2.: rewrite vid.inc.php when all recording finished !
	echo "<video controls style='max-width: 960px;'>" >> $WorkDir/vid.inc.php
	echo "<source src=$tsname type='video/mp4'>" >> $WorkDir/vid.inc.php
	echo "</video>" >> $WorkDir/vid.inc.php
	rm $WorkDir/$tsbase?.mp4	# remove obsolete mp4 chunks 29.2.
else
	# convert HLS to mp4
	if [ -f $WorkDir/$tsbase.mp4 ];then 
		rm $WorkDir/$tsbase.mp4	# avoid ffmpeg Error if mp4 File exists
	fi
	if [ "$verbose" ];then
		echo "ffmpeg -i $RecFile -codec copy $WorkDir/$tsbase.mp4"
		exit
	fi
	ffmpeg -i $RecFile -codec copy $WorkDir/$tsbase.mp4
	# TODO: remove obsolete .ts snippets, rewrite vid.inc.php for final mp4 only
fi

