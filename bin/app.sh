#/usr/bin/env bash

#
# DJANGOPOSER 2022 written by ALEKSANDR GORETOY <alex@goretoy.com>
#
# Use this script to assist working on your django projects in 2022 as you listen to UnlimitedHangout.com Podcast
#
# Copyright 9/11/2022 ALEKSANDR GORETOY <alex@goretoy.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

function help() {
    echo "./bin/app.sh <operation> <project> <app> [endpoint] [deps]"
    # echo "docker-compose run admin /bin/bash /src/bin/app.sh <operation> <project> <app> [endpoint] [deps]"
    echo
    echo "operation can be one of create, remove"
    echo "endpoint can be auto or any string as endpoint prefix"
}

OP="${1}"
PROJ="${2}"
APP="${3}"
ENDPOINT="${4}"
DEPS="${@:5}"

# to undo
# rm -rf ./$PROJ/$APP
# awk '!/$APP.apps./' ./$PROJ/config/settings.py
if [ "$OP" == "" ] || [ "$PROJ" == "" ] || [ "$APP" == "" ]; then
    help
    exit 1
fi

if [ "$OP" == "remove" ]; then
    if [ -d "/src/$PROJ/$APP" ]; then
        if [ ! -d "/src/$PROJ/.trash" ]; then
            echo "CREATED /src/$PROJ/.trash/"
            mkdir -p "/src/$PROJ/.trash"
        fi
        echo "REMOVING /src/$PROJ/$APP"
        # rm -rf "/src/$PROJ"
        mv "/src/$PROJ/$APP" "/src/$PROJ/.trash/"
        echo "MOVED $APP to /src/$PROJ/.trash/"
    else
        if [ -d "./$PROJ/$APP" ]; then
            if [ ! -d "./$PROJ/.trash" ]; then
                echo "CREATED ./$PROJ/.trash/"
                mkdir -p "./$PROJ/.trash"
            fi
            echo "REMOVING ./$PROJ/$APP"
            # rm -rf "/src/$PROJ"
            mv "./$PROJ/$APP" "./$PROJ/.trash/"
            echo "MOVED $APP to ./$PROJ/.trash/"
        else
            echo "APP NOT FOUND /src/$PROJ/$APP"
        fi
    fi
    exit 0
fi

if [ "$OP" == "create" ]; then
    if [ -d "./$PROJ" ] && [ ! -d "/src/$PROJ" ]; then
        if [ -d "./$PROJ/$APP" ]; then
            echo "$APP APP EXISTS"
            exit 0
        fi

        if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" == "" ]; then
            echo "$PROJ: CONTAINER NOT RUNNING"
            echo "docker-compose build $PROJ --no-cache && docker-compose up -d $PROJ --remove-orphans"
            echo "./bin/project.sh build $PROJ && ./bin/project.sh start $PROJ"
            echo "  - and then run the create command with the same params again"
            echo "    to create the app inside the project after the project container starts"
            echo ">> ./bin/project.sh $OP $PROJ auto $APP $ENDPOINT $DEPS"
            exit 1
        fi
        # # step 1: create project since it doesn't exist already
        # if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" == "" ]; then
        #     if [ "$(grep $PROJ: ./docker-compose.yml)" != "" ]; then
        #         echo "1:    RUNNING docker-compose up -d $PROJ --remove-orphans"
        #         docker-compose up -d "$PROJ" --remove-orphans
        #         sleep 3
        #     else
        #         echo "SERVICE ERROR $PROJ: NOT FOUND IN docker-compose.yml"
        #         exit 1
        #     fi
        # fi

        # step 2: backup requirements.txt just in case
        echo "2:    MOVING $PROJ/requirements.txt > $PROJ/requirements.txt.bak"
        if [ -f "$PROJ/requirements.txt" ]; then
            cp "$PROJ/requirements.txt" "$PROJ/requirements.txt.bak"
        fi

        if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" == "" ]; then
            echo "$PROJ: CONTAINER NOT RUNNING"
            exit 1
        fi
        # step 3: install python default deps(need to make sure) along with any project specific deps
        echo "3:    RUNNING docker exec -it $PROJ pip3 install django djangorestframework django-extensions django-crispy-forms crispy-tailwind python-webpack-boilerplate psycopg2 pyyaml jq yq requests $DEPS"
        docker exec -it "$PROJ" pip3 install \
            django \
            djangorestframework \
            django-extensions \
            django-crispy-forms \
            crispy-tailwind \
            python-webpack-boilerplate \
            psycopg2 \
            pyyaml \
            jq \
            yq \
            requests $DEPS
        sleep 3

        if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" == "" ]; then
            echo "$PROJ: CONTAINER NOT RUNNING"
            exit 1
        fi
        # step 4: pip freeze to make sure it's current
        echo "4:    RUNNING docker exec -it $PROJ pip3 freeze > $PROJ/requirements.txt"
        docker exec -it "$PROJ" pip3 freeze > "$PROJ/requirements.txt"
        sleep 3

        # step 5: build project docker container
        echo "5:    RUNNING docker-compose build --no-cache $PROJ"
        docker-compose build --no-cache "$PROJ"
        sleep 3

        # step 6: restart the built container
        # TODO: need to fix step 5 and step 6
        echo "6:    RUNNING docker-compose restart $PROJ"
        docker-compose restart "$PROJ"
        sleep 3

        # step 7: create django app inside django project
        echo "7:    RUNNING docker-compose run $PROJ python manage.py startapp $APP"
        docker-compose run "$PROJ" python manage.py startapp "$APP"
        sleep 3

        # step 8: update settings to prep for development 
        if [ -f "./$PROJ/$APP/apps.py" ]; then
            echo "8:    CHANGING app_config name in ./$PROJ/$APP/apps.py"
            LINE="$(grep -n "name = " ./$PROJ/$APP/apps.py | head -n1 | sed 's/:/ /' | awk '{print $1}')"
            head -n $(( $LINE - 1 )) "./$PROJ/$APP/apps.py" > /tmp/apps.py
            echo "    name = '$PROJ.$APP'" >> /tmp/apps.py
            tail -n +$(( $LINE + 1 )) "./$PROJ/$APP/apps.py" >> /tmp/apps.py
            mv /tmp/apps.py "./$PROJ/$APP/apps.py"
            # grab the created app_config name and add it to INSTALLED_APPS
            NAME="$(grep 'class ' "./$PROJ/$APP/apps.py" | sed 's/(/ /'|awk '{print $2}')"
            if [ "$NAME" != "" ]; then
                APP_CONFIG="$APP.apps.$NAME"
                echo "9:    ADDING $APP_CONFIG to INSTALLED_APPS in ./$PROJ/config/settings.py"
                LINE1="$(grep -n 'INSTALLED_APPS = ' ./$PROJ/config/settings.py | sed 's/:/ /' | awk '{print $1}')"
                LINE2="$(tail -n +$LINE1 ./$PROJ/config/settings.py | grep -n ']' | head -n 1 | sed 's/:/ /' | awk '{print $1}')"
                head -n $(( $LINE1 + $LINE2 - 2 )) "./$PROJ/config/settings.py" > /tmp/settings.py
                echo "    '"$APP_CONFIG"'," >> /tmp/settings.py
                tail -n +$(( $LINE1 + $LINE2 - 1 )) "./$PROJ/config/settings.py" >> /tmp/settings.py
                mv /tmp/settings.py "./$PROJ/config/settings.py"
            fi

            # create directories
            echo "10:   RUNNING mkdir ./$PROJ/$APP/{templates,fixtures}"
            mkdir "./$PROJ/$APP/"{"templates","fixtures"}

            # step 10: inject '$APP/templates' into TEMPLATES DIRS[]
            echo "11:   ADDING '$APP/templates', to DIRS in ./$PROJ/config/settings.py"
            LINE1="$(grep -n "'DIRS': " ./$PROJ/config/settings.py | head -n1 | sed 's/:/ /' | awk '{print $1}')"
            LINE2="$(tail -n +$LINE1 ./$PROJ/config/settings.py | grep -n '],' | head -n 1 | sed 's/:/ /' | awk '{print $1}')"
            head -n $(( $LINE2 - 1 )) "./$PROJ/config/settings.py" > /tmp/settings.py
            echo "            '$APP/templates'," >> /tmp/settings.py
            tail -n +$(( $LINE2 )) "./$PROJ/config/settings.py" >> /tmp/settings.py
            mv /tmp/settings.py "./$PROJ/config/settings.py"

            if [ ! -f "./$PROJ/$APP/endpoint.py" ]; then
                # create endpoint.py
                echo "12:   CREATING ENDPOINT in ./$PROJ/$APP/endpoint.py"
                if [ "$ENDPOINT" == "auto" ] || [ "$ENDPOINT" == "" ]; then
                    ENDPOINT=""
                fi
                echo "ENDPOINT = '$ENDPOINT'" > "./$PROJ/$APP/endpoint.py"
            fi
            if [ ! -f "./$PROJ/$APP/urls.py" ]; then
                echo "13:   CREATING FILE ./$PROJ/$APP/urls.py"
                echo "from rest_framework.routers import DefaultRouter" > "./$PROJ/$APP/urls.py"
            else
                echo "13:   FILE EXISTS ./$PROJ/$APP/urls.py"
                head -n 3 "./$PROJ/$APP/urls.py"
            fi
            if [ ! -f "./$PROJ/$APP/permissions.py" ]; then
                echo "14:   CREATING FILE ./$PROJ/$APP/permissions.py"
                echo "from rest_framework.permissions import BasePermission" > "./$PROJ/$APP/permissions.py"
            else
                echo "14:   FILE EXISTS ./$PROJ/$APP/permissions.py"
                head -n 3 "./$PROJ/$APP/permissions.py"
            fi
            if [ ! -f "./$PROJ/$APP/serializers.py" ]; then
                echo "15:   CREATING FILE ./$PROJ/$APP/serializers.py"
                echo "from rest_framework import serializers" > "./$PROJ/$APP/serializers.py"
            else
                echo "15:   FILE EXISTS ./$PROJ/$APP/serializers.py"
                head -n 3 "./$PROJ/$APP/serializers.py"
            fi
        else
            echo "$?: docker-compose failed adding $APP to $PROJ/config/settings.py"
            exit 1
        fi
    else
        echo "$PROJ NOT FOUND"
        echo "maybe you need to run ./bin/project.sh create $PROJ"
        exit 1
    fi
    exit 0
fi
