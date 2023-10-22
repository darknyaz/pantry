#!/bin/sh

get_battery()
{
    icons="󰁺󰁻󰁼󰁽󰁾󰁿󰂀󰂁󰂂󰁹"

    batt=`cat /sys/class/power_supply/BAT0/capacity`
    stat=`cat /sys/class/power_supply/BAT0/status`

    numb=$((batt/10))
    # Символ занимает 4 байта. Программа cut не работает посимвольно с UTF8.
    icon=$(echo "$icons" | cut -b $((numb*4+1))-$((numb*4+4)))

    if test "$stat" = "Charging"; then
        icon="${icon}󱐋"
    fi

    echo "$icon $batt%"
}

get_temperature()
{
    temp=$(cat /sys/devices/platform/coretemp.0/hwmon/*/temp1_input | head -n 1)

    echo $((temp/1000))
}

get_volume_pulse()
{
    # Получаем номер активного источника звука.
    sink=$(pactl list short sinks | grep RUNNING | sed -e 's,^\([0-9][0-9]*\)[^0-9].*,\1,' | head -n 1)

    # Получаем текущее значение громкости для первого активного источника. Если в данный момент
    # нет активных источников, звук не воспроизводится, на выходе будет пустая строка.
    volume=$(LC_ALL=C pactl list sinks \
        | perl -e '$f=join("",<>); print $& if $f=~/(?s)Sink #'$sink'\n.*/m' \
        | grep '^[[:space:]]Volume:' \
        | head -n 1 \
        | sed -e 's,.* \([0-9][0-9]*\)%.*,\1♪,')

    echo "$volume"
}

get_volume()
{
    icon="󰕿"
    volume=$(get_volume_pulse)

    echo "$icon $volume"
}

get_lang()
{
    if command -v xkb-switch; then
        lang=$(xkb-switch | tr 'a-z' 'A-Z')
    elif command -v xkblayout-state; then
        lang=$(xkblayout-state print %s | tr 'a-z' 'A-Z')
    else
        lang=""
    fi

    echo "$lang"
}

get_brightness()
{
    brightness=$(xbacklight -get | sed 's/\..*//')

    echo "$brightness"
}

update_status()
{
    time=$(date +"%d.%m %H:%M")

    batt=$(get_battery)
    temp=$(get_temperature)
    volume=$(get_volume)
    lang=$(get_lang)

    #brightness=$(get_brightness)

    xsetroot -name " $temp°C $batt $volume $lang $time"
}

my_pid=$$
if [ "$1" = "loop" ]; then
    # Список PID данного скрипта кроме PID текущего процесса.
    pids=$(pgrep -x $(basename $0) | grep -v $my_pid)

    if test -n "$pids"; then
        for pid in "$pids"; do
            kill $pid
        done
    fi

    while [ 1 ]; do
        update_status
        sleep 2
    done
else
    update_status
fi
