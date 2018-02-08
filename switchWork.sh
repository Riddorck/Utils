#!/bin/bash

current=$(i3-msg -t get_workspaces | jq '.[] | select(.focused==true).num')
last=$(i3-msg -t get_workspaces | jq '.[-1].num')
first=$(i3-msg -t get_workspaces | jq '.[0].num')

if [ "${1}" == "+" ]; then
        let new=${current}+1
        if [ ${current} == ${last} ]; then
                i3-msg workspace ${first}
        else
                i3-msg workspace ${new}
        fi
elif [ "${1}" == "-" ]; then
        let new=${current}-1
        if [ ${current} == 1 ]; then
                i3-msg workspace ${last}
        else
                i3-msg workspace ${new}
        fi
fi
