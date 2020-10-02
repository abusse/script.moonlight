#!/bin/bash

. /etc/profile

if [ -f /tmp/moonlight.start ]; then
	rm "/tmp/moonlight.start"
fi

echo -e "defaults.pcm.!card 0\ndefaults.pcm.!device 3" > ~/.asoundrc
KODI_AE_SINK=ALSA /usr/bin/kodi &

while true; do
	if [ -f /tmp/moonlight.start ]; then
		source /tmp/moonlight.start
		rm "/tmp/moonlight.start"

		MOONLIGHT_ARG="stream"

		if [ "$MOON_RESOLUTION" = "720p" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --720"
		elif [ "$MOON_RESOLUTION" = "1080p" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --1080"
		elif [ "$MOON_RESOLUTION" = "1440p" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --1440"
		elif [ "$MOON_RESOLUTION" = "4k" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --4k"
		elif [ "$MOON_RESOLUTION" = "Custom" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --resolution ${MOON_WIDTH_RESOLUTION}x${MOON_HEIGHT_RESOLUTION}"
		else
			MOONLIGHT_ARG="$MOONLIGHT_ARG --720"
		fi

		if [ "$MOON_FRAMERATE" != "" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --fps $MOON_FRAMERATE"
		else
			MOONLIGHT_ARG="$MOONLIGHT_ARG --fps 30"
		fi

		if [ "$MOON_BITRATE" != "" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --bitrate $MOON_BITRATE"
		fi

		if [ "$MOON_PACKETSIZE" != "" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --packetsize $MOON_PACKETSIZE"
		fi

		if [ "$MOON_VSYNC" = "true" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --vsync"
		fi

		if [ "$MOON_FRAM_PACING" = "true" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --frame-pacing"
		fi

		if [ "$MOON_AUDIO" = "5.1 Surround" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --audio-config 5.1-surround"
		elif [ "$MOON_AUDIO" = "7.1 Surround" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --audio-config 7.1-surround"
		else
			MOONLIGHT_ARG="$MOONLIGHT_ARG --audio-config stereo"
		fi

		if [ "$MOON_MULTI_CONTROLLER" = "true" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --multi-controller"
		fi

		if [ "$MOON_GAME_MODE" = "true" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --game-optimization"
		fi

		if [ "$MOON_HOST_AUDIO" = "true" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --audio-on-host"
		fi

		if [ "$MOON_CODEC" = "H.264" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --video-codec H.264"
		elif [ "$MOON_AUDIO" = "HEVC" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --video-codec HEVC"
		else
			MOONLIGHT_ARG="$MOONLIGHT_ARG --video-codec auto"
		fi

		if [ "$MOON_DECODER" = "software" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --video-decoder software"
		elif [ "$MOON_AUDIO" = "hardware" ]; then
			MOONLIGHT_ARG="$MOONLIGHT_ARG --video-decoder hardware"
		else
			MOONLIGHT_ARG="$MOONLIGHT_ARG --video-decoder auto"
		fi

		MOONLIGHT_ARG="$MOONLIGHT_ARG --quit-after"

		echo $MOONLIGHT_ARG > /tmp/moonlight.args

		# Kodi does not support signals, so we do it the hard way
		killall kodi
		killall kodi-x11

		sleep 3

		rm ~/.asoundrc

		pulseaudio -k
		pulseaudio -D
		xrandr --output HDMI-1 --rate 60 --mode ${KODI_WIDTH}x${KODI_HEIGHT} --pos 0x0
		/usr/bin/moonlight-qt $MOONLIGHT_ARG $MOON_SERVER_ADDR "$MOON_APP" 2>&1 > /tmp/moonlight.log

		pulseaudio -k
		echo -e "defaults.pcm.!card 0\ndefaults.pcm.!device 3" > ~/.asoundrc
		KODI_AE_SINK=ALSA /usr/bin/kodi &
	fi
	sleep 1
done
