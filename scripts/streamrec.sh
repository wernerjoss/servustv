#!/bin/bash
# Usage: streamrec.sh (direct Call) or
# at 06:30 tomorrow -f ~/bin/streamrec.sh	# scheduled call via at

# default Parameters:
UserAgent="Mozilla/5.0_(Windows_NT_10.0_Win64_x64)_AppleWebKit/537.36_(KHTML_like_Gecko)_Chrome/71.0.3554.0_Safari/537.36"
# UserAgent="VLC/3.0.20-0+deb12u1"
# Note: UserAgent may NOT contain Blanks, Semicolons etc. !
StreamUrl="https://stv-live.akamaized.net/hls/live/2031011/lingeoSTVATwebPri/master.m3u8"	# Servus TV AT live
# StreamUrl="https://rbmn-live.akamaized.net/hls/live/590964/BoRB-AT/master.m3u8"       # Red Bull TV live
RecTime=300	# Seconds
WorkDir="/var/www/html/video"	# no Trailing Slash !
# WorkDir="$HOME/tmp/video"	# local Test - must NOT be ~/tmp/video !
RecFile="sprint.mp4"	# just File Name without Path
NumParts=2	# #No. of Parts
# dryrun=1
LogFile=/tmp/streamrec.log

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
tsbase=$(echo $tsname | awk -F . '{print $1}')
type=$(echo $tsname | awk -F . '{print $2}')

if [ "$dryrun" ];then
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
absRecFile="$WorkDir/$tsbase.$type"

if [ ! -f $LogFile ];then
	touch $LogFile
fi
d=$(date)
logmsg="recording started at: $d"
echo $logmsg | tee -a $LogFile

if [ "$type" = "mp4" ];then
	for (( Num=0; Num<NumParts; Num++ )) ; {
		incRecFile="$tsbase$Num.mp4"
		absRecFile="$WorkDir/$tsbase$Num.mp4"	# absRecFile is now numbered snippet !
		if [ -f "$absRecFile" ]; then
			echo "removing $absRecFile"
			rm -f $absRecFile
		fi
		if [ ! -z $dryrun ]; then
			echo $absRecFile
			echo "Simulation, nothing recorded :-)"
		else
			# Video Recording goes here
			echo "recording $absRecFile" | tee -a $LogFile
			ffmpeg -n -user_agent $UserAgent -i $StreamUrl -t $RecTime -c copy $absRecFile	# mp4 Recording, reloded :-)
			# display recorded part $Num AFTER record finished
			echo "<video controls style='max-width: 960px;'>" >> $WorkDir/vid.inc.php
			echo "<source src=$incRecFile type='video/mp4'>" >> $WorkDir/vid.inc.php
			echo "</video>" >> $WorkDir/vid.inc.php
			sleep 5	#	sleep $(( $RecTime / 10 )) too much :-)
        fi
	}
	absRecFile="$WorkDir/$tsbase.$type"	# restore Name for Result
else
	if [ ! -z $dryrun ]; then
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
		echo "recording $RecFile" | tee -a $LogFile
		# -crf 30 reduces size significantly, but causes random losses 06.03. !
		# ffmpeg -n -user_agent $UserAgent -i $StreamUrl -t $RecTime -c:v libx264 -crf 21 -preset veryfast -c:a aac -b:a 128k -ac 2 -f hls -hls_time 4 -hls_playlist_type event $absRecFile
		# skip compression -crf...
		# ffmpeg -n -user_agent $UserAgent -i $StreamUrl -t $RecTime -preset veryfast -c:a aac -b:a 128k -ac 2 -f hls -hls_time 4 -hls_playlist_type event $absRecFile
		# new approach see https://www.martin-riedl.de/2018/08/24/using-ffmpeg-as-a-hls-streaming-server-part-2/
		# ffmpeg -n -user_agent $UserAgent -i $StreamUrl -t $RecTime -c:v libx264 -crf 21 -preset veryfast -g 25 -sc_threshold 0 -c:a aac -b:a 128k -ac 2 -f hls -hls_time 8 -hls_playlist_type event $absRecFile
		ffmpeg -n -user_agent $UserAgent -i $StreamUrl -t $RecTime -preset veryfast -g 25 -sc_threshold 0 -c:a aac -b:a 128k -ac 2 -f hls -hls_time 8 -hls_playlist_type event $absRecFile
		
	fi
fi
d=$(date)
logmsg="finished recording at: $d"
echo $logmsg | tee -a $LogFile
	
if [ -f "$WorkDir/videos.txt" ];then
	rm $WorkDir/videos.txt
fi

d=$(date)	
logmsg="$d : creating final video: $tsbase.mp4"
echo $logmsg | tee -a $LogFile

if [ "$type" = "mp4" ];then
	if [ -f $WorkDir/$tsbase.mp4 ];then 
		rm $WorkDir/$tsbase.mp4	# avoid ffmpeg Error if mp4 File exists
	fi
	for f in $WorkDir/$tsbase*.mp4; do echo "file '$f'" >> $WorkDir/videos.txt; done
	if [ "$dryrun" ];then
		echo "command:"
		echo "ffmpeg -safe 0 -f concat -i $WorkDir/videos.txt -c copy $absRecFile"
		exit
	fi
	# scale final video to 1280	06.03.
	# ffmpeg -safe 0 -f concat -i $WorkDir/videos.txt -vf scale=1280:-2 $absRecFile	# scaling later, see cropvideo.sh
	ffmpeg -safe 0 -f concat -i $WorkDir/videos.txt -c copy $absRecFile
	# display final recorded Video $Num AFTER record finished
	echo "<h3>Final Video $tsname:</h3>" > $WorkDir/vid.inc.php	# 28.2.: rewrite vid.inc.php when all recording finished !
	echo "<video controls style='max-width: 960px;'>" >> $WorkDir/vid.inc.php
	echo "<source src=$tsname type='video/mp4'>" >> $WorkDir/vid.inc.php
	echo "</video>" >> $WorkDir/vid.inc.php
	d=$(date)	
	logmsg="$d : finished creating final video: $tsbase.mp4"
	# echo $logmsg | tee -a $LogFile
	# if [ -f $absRecFile ]; then
	# 	rm $WorkDir/$tsbase?.mp4	# remove obsolete mp4 chunks 29.2.
	# fi
else
	# convert HLS to mp4
	if [ -f $WorkDir/$tsbase.mp4 ];then 
		rm $WorkDir/$tsbase.mp4	# avoid ffmpeg Error if mp4 File exists
	fi
	if [ "$dryrun" ];then
		echo "ffmpeg -i $RecFile -codec copy $WorkDir/$tsbase.mp4"	# convert m3u8 to mp4
		exit
	fi
	# ffmpeg -i $absRecFile -vf scale=1280:-2 $WorkDir/$tsbase.mp4	# convert m3u8 to scaled mp4	# scaling later, see cropvideo.sh
	ffmpeg -i $absRecFile -codec copy $WorkDir/$tsbase.mp4	# convert m3u8 to mp4
	# DONE: remove obsolete .ts snippets, rewrite vid.inc.php for final mp4 only:
	echo "<h3>Final Video $tsbase.mp4:</h3>" > $WorkDir/vid.inc.php	# 28.2.: rewrite vid.inc.php when all recording finished !
	echo "<video controls style='max-width: 960px;'>" >> $WorkDir/vid.inc.php
	echo "<source src=$tsbase.mp4 type='video/mp4'>" >> $WorkDir/vid.inc.php
	echo "</video>" >> $WorkDir/vid.inc.php
	# exit	# skip cleanup for now 04.03.
	d=$(date)
	logmsg="$d : finished creating final video $tsbase.mp4"
	# echo $logmsg | tee -a $LogFile
	# sleep $RecTime
	# if [ -f $WorkDir/$tsbase.mp4 ]; then
	# 	rm $WorkDir/*.ts
	# fi
fi
d=$(date)	
logmsg="$d : finished final video: $tsbase.mp4, streamrec.sh done"
echo $logmsg | tee -a $LogFile
