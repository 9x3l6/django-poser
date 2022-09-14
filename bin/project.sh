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
    echo "./bin/project.sh <operation> <project> [port] [app] [endpoint] [deps]"
    echo "./bin/project.sh create mail auto mailer auto celery"
    echo "./bin/project.sh create doc auto docs auto sphinx django-sphinx-view sphinxcontrib-packages"
    echo "operation can be one of nginx, check, snap, fresh, remove, kill, install, start, logs, tail"
}

OP="${1}"
PROJ="${2}"
PORT="${3}"
APP="${4}"
ENDPOINT="${5}"
DEPS="${@:6}"

function nginxLocation() {
    BASE="$1"
    PROJ="$2"
    PORT="$3"
    if [ ! -d "$BASE/nginx/locations.d/" ]; then
        mkdir -p "$BASE/nginx/locations.d/"
    fi
    if [ ! -f "$BASE/nginx/locations.d/$PROJ:$PORT.conf" ]; then
        cat >> "$BASE/nginx/locations.d/$PROJ:$PORT.conf" <<-EOM
location /$PROJ {
    proxy_pass http://$PROJ.nginx/;
    proxy_set_header X-Real-IP  \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-NginX-Proxy true;
    proxy_set_header Host \$host;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_http_version 1.1;
    proxy_ssl_session_reuse off;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_read_timeout 20d;
    proxy_buffering off;
    proxy_cache_bypass \$http_upgrade;
    # proxy_redirect off;
}
EOM
    fi
}
function nginxUpstream() {
    BASE="$1"
    PROJ="$2"
    PORT="$3"
    if [ ! -d "$BASE/nginx/upstreams.d/" ]; then
        mkdir -p "$BASE/nginx/upstreams.d/"
    fi
    if [ ! -f "$BASE/nginx/upstreams.d/$PROJ:$PORT.conf" ]; then
        cat >> "$BASE/nginx/upstreams.d/$PROJ:$PORT.conf" <<-EOM
upstream $PROJ.nginx {
    server $PROJ:$PORT;
}
EOM
    fi
}
if [ "$OP" == "nginx" ]; then
    if [ "$PROJ" != "" ] && [ "$PORT" != "" ]; then
        if [ -d "/src" ]; then
            nginxLocation "/src" "$PROJ" "$PORT"
            nginxUpstream "/src" "$PROJ" "$PORT"
        else
            nginxLocation "./" "$PROJ" "$PORT"
            nginxUpstream "./" "$PROJ" "$PORT"
        fi
    else
        echo "PROJECT NAME AND PORT REQUIRED"
        echo "$0 <operation> <project> <port>"
        echo "$0 nginx <project> <port>"
        echo "$0 nginx test 9999"
        exit 1
    fi
fi

# check operation
# ./bin/project.sh <operation> [params|default]
# ./bin/project.sh check [params|2]
if [ "$OP" == "check" ] || [ "$OP" == "check-system" ]; then
    for p in db web; do
        if [ "$(docker ps | awk '{print $(NF)}' | grep "$p")" != "" ]; then
            docker-compose logs "$p" --tail ${2:-"2"}
        fi
    done
fi
if [ "$OP" == "check" ] || [ "$OP" == "check-projects" ]; then
    for p in $(cat projects.txt | xargs); do  # db web admin
        PROJ="$(echo "$p" | sed 's/:/ /' | awk '{print $1}')"
        if [ "$PROJ" != "" ] && [[ "$PROJ" != "#"* ]] && [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" != "" ]; then
            docker-compose logs "$PROJ" --tail ${2:-"2"}
        fi
        if [ ! -d "$PROJ" ]; then
            echo "WARNING: projects.txt has '$PROJ' and the folder is missing."
            echo "Please remove '$p' from projects.txt or run ./bin/project.sh create $PROJ"
        fi
    done
    exit 0
fi
if [[ "$OP" = "check"* ]]; then
    exit 0
fi

if [ "$OP" == "fresh" ]; then
    $0 kill
    if [ -d "./data" ]; then
        rm -rf ./data
    fi
    echo "1:    RUNNING $0 build"
    $0 build
    echo "2:    RUNNING $0 start"
    $0 start
    if [ "$?" != "0" ]; then
        echo "FAILED STARTING"
        exit 1
    fi
    exit 0
fi

# snap operation
# ./bin/project.sh <operation> [project]
# ./bin/project.sh snap admin
if [ "$OP" == "snap" ]; then
    if [ "$PROJ" != "" ]; then
        $0 kill "$PROJ"
        $0 build "$PROJ"
        $0 start "$PROJ"
        $0 logs "$PROJ"
    else
        $0 fresh
        $0 logs
    fi
    exit 0
fi

# start operation
# ./bin/project.sh start 
if [ "$OP" == "start" ]; then
    if [ "$PROJ" != "" ]; then
        if [ -d "$PROJ" ]; then
            if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" == "" ]; then
                echo "RUNNING: docker-compose up -d $PROJ --remove-orphans"
                docker-compose up -d "$PROJ" --remove-orphans
                sleep 1
            else
                echo "RUNNING: docker-compose restart $PROJ"
                docker-compose restart "$PROJ"
                sleep 1
            fi
        else
            echo "DJANGOPOSER ERROR: $PROJ DIRECTORY MISSING"
        fi
    else
        echo "RUNNING: docker-compose up -d --remove-orphans"
        docker-compose up -d --remove-orphans
        sleep 1
    fi
    exit 0
fi

# kill operation
# ./bin/project.sh <operation> [project]
# ./bin/project.sh kill
# ./bin/project.sh kill admin
if [ "$OP" == "kill" ]; then
    if [ "$PROJ" != "" ]; then
        docker-compose kill "$PROJ"
    else
        docker-compose kill
    fi
    exit 0
fi

# stop operation
# ./bin/project.sh <operation> [project]
# ./bin/project.sh stop
# ./bin/project.sh stop admin
if [ "$OP" == "stop" ]; then
    if [ "$PROJ" != "" ]; then
        docker-compose stop "$PROJ"
    else
        docker-compose stop
    fi
    exit 0
fi

# build operation
# ./bin/project.sh <operation> <project>
# ./bin/project.sh build admin
if [ "$OP" == "build" ]; then
    if [ "$PROJ" != "" ]; then
        echo "RUNNING: docker-compose build --no-cache $PROJ"
        docker-compose build --no-cache $PROJ
    else
        echo "RUNNING: docker-compose build --no-cache"
        docker-compose build --no-cache
    fi
    sleep 1
    exit 0
fi

if [ "$PROJ" == "" ]; then
    help
    echo ""
    echo "PROJECT NAME REQUIRED $OP"
    exit 1
fi

# exec operation, access to project shell
# ./bin/project.sh <operation> <project> [params|/bin/bash]
# ./bin/project.sh exec <project>
# ./bin/project.sh exec admin
# ./bin/project.sh exec docs sphinx-quickstart
if [ "$OP" == "exec" ]; then
    if [ "$PROJ" != "" ]; then
        docker exec -it "$PROJ" ${3:-"/bin/bash"} ${@:4}
        sleep 1
    fi
    exit 0
fi

# manage operation, access to all manage.py subcommands
# ./bin/project.sh <operation> <project> [params|/bin/bash]
# ./bin/project.sh manage <project>
# ./bin/project.sh manage admin createsuperuser --username admin --email alex@goretoy.com
# ./bin/project.sh manage admin loaddata users.yaml
# ./bin/project.sh manage admin test
# ./bin/project.sh manage admin shell
if [ "$OP" == "manage" ]; then
    if [ "$PROJ" != "" ] && [ -d "./$PROJ" ]; then
        if [ "$PROJ" == "db" ] || [ "$PROJ" == "web" ] || [ "$PROJ" == "mail.dev" ]; then
            docker exec -it "$PROJ" ${3:-"/bin/bash"}
            sleep 1
        else
            if [ ! -d "./$PROJ/static/$PROJ" ]; then
                echo "CREATING DIRECTORY ./$PROJ/static/$PROJ"
                mkdir "./$PROJ/static/$PROJ"
            fi
            echo "RUNNING: docker-compose run $PROJ python manage.py ${@:3}"
            docker-compose run "$PROJ" python manage.py "${@:3}"
            sleep 1
        fi
    fi
    exit 0
fi

function findProjectInDC() {
    BASE="$1"
    PROJ="$2"
    FOUND="$(grep -n "$PROJ:" "$BASE/docker-compose.yml")"
    if [ "$FOUND" != "" ]; then
        echo "FOUND $PROJ: in docker-compose.yml"
        echo "Please remove it manually if you want"
    fi
}
function trashProject() {
    BASE="$1"
    PROJ="$2"
    if [ ! -d "$BASE/.trash/$PROJ" ]; then
        echo "CREATED $BASE/.trash/$PROJ/"
        mkdir -p "$BASE/.trash/$PROJ/"
    fi
    echo "MOVING $BASE/$PROJ/ to $BASE/.trash/$PROJ/"
    (cd "$BASE/$PROJ" && tar c .) | (cd "$BASE/.trash/$PROJ" && tar xf -) && rm -rf "$BASE/$PROJ"
}

# remove operation
# ./bin/project.sh <operation> <project>
# ./bin/project.sh remove project
if [ "$OP" == "remove" ]; then
    if [ "$PROJ" != "" ]; then
        if [ "$PROJ" == "admin" ] || [ "$PROJ" == "bin" ] || [ "$PROJ" == "data" ] || [ "$PROJ" == "web" ] || [ "$PROJ" == "nginx" ] || [ "$PROJ" == "ssl" ]; then
            echo -n "NOT REMOVING RESERVED DIRECTORY $PROJ"
        else
            echo "1:  SEARCHING for $PROJ: in docker-compose.yml"
            if [ -f "/src/docker-compose.yml" ]; then
                findProjectInDC "/src" "$PROJ"
            else
                findProjectInDC "./" "$PROJ"
            fi
            # move to .trash
            echo "2:  MOVING $PROJ directory to .trash"
            if [ -d "/src/$PROJ" ]; then
                trashProject "/src" "$PROJ"
            else
                trashProject "./" "$PROJ"
            fi
            # remove nginx location config for project
            NGINX_PATH="$(find "/src/nginx/locations.d" -type f -iname "$PROJ"':*'conf)"
            if [ -d "/src/nginx/locations.d" ] && [ -f "$NGINX_PATH" ]; then
                echo "3:  REMOVING NGINX LOCATION CONFIG FILE $NGINX_PATH"
                rm "$NGINX_PATH"
            else
                NGINX_PATH="$(find "./nginx/locations.d" -type f -iname "$PROJ"':*'conf)"
                if [ -d "./nginx/locations.d" ] && [ -f "$NGINX_PATH" ]; then
                    echo "3:  REMOVING NGINX LOCATION CONFIG FILE $NGINX_PATH"
                    rm "$NGINX_PATH"
                fi
            fi
            # remove project from projects.txt used by check operation
            if [ "$(grep $PROJ /src/projects.txt)" != "" ]; then
                echo "4:  REMOVING $PROJ from /src/projects.txt file"
                echo "$(sed 's/'"$PROJ"'//g' /src/projects.txt | xargs -n 1)" > /src/projects.txt
            elif [ "$(grep $PROJ ./projects.txt)" != "" ]; then
                echo "4:  REMOVING $PROJ from ./projects.txt file"
                echo "$(sed 's/'"$PROJ"'//g' ./projects.txt | xargs -n 1)" > ./projects.txt
            fi
        fi
    else
        echo "PROJECT NAME REQUIRED"
        exit 1
    fi
    exit 0
fi

# install operation
# ./bin/project.sh install <project> <deps>
# ./bin/project.sh install admin django-fernet-fields
if [ "$OP" == "install" ]; then
    if [ "$PROJ" != "" ]; then
        if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" != "" ]; then
            if [[ "$#" -lt "3" ]]; then
                help
                echo ""
                echo "DEPENDENCIES ARE REQUIRED"
                exit 1
            fi
            echo "1:  RUNNING docker exec -it "$PROJ" pip3 install "${@:3}""
            docker exec -it "$PROJ" pip3 install "${@:3}"
            sleep 3
            echo "2:  RUNNING docker exec -it "$PROJ" pip3 freeze > $PROJ/requirements.txt"
            docker exec -it "$PROJ" pip3 freeze > "$PROJ/requirements.txt"
            sleep 1
        else
            help
            echo ""
            echo "PROJECT NOT RUNNING"
            echo "./bin/project.sh start $PROJ"
            exit 1
        fi
    fi
    exit 0
fi

# migrate operation
# ./bin/project.sh <operation> <project>
# ./bin/project.sh migrate admin
if [ "$OP" == "migrate" ]; then
    if [ "$PROJ" != "" ] && [ -d "$PROJ" ] && [ -f "$PROJ/manage.py" ]; then
        if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" == "" ]; then
            echo "$PROJ: CONTAINER NOT RUNNING"
            exit 1
        fi
        echo "1:  RUNNING docker-compose run $PROJ python manage.py makemigrations"
        docker-compose run "$PROJ" python manage.py makemigrations
        sleep 3
        if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" == "" ]; then
            echo "$PROJ: CONTAINER NOT RUNNING"
            exit 1
        fi
        echo "2:  RUNNING docker-compose run $PROJ python manage.py migrate"
        docker-compose run "$PROJ" python manage.py migrate
        sleep 1
    fi
    exit 0
fi

# test operation
# ./bin/project.sh <operation> <project> [params]
# ./bin/project.sh test <project>
# ./bin/project.sh test video
# ./bin/project.sh test video --help
if [ "$OP" == "test" ]; then
    if [ "$PROJ" != "" ] && [ -d "$PROJ" ] && [ -f "$PROJ/manage.py" ]; then
        if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" == "" ]; then
            echo "$PROJ: CONTAINER NOT RUNNING"
            exit 1
        fi
        echo "1:  RUNNING docker-compose run $PROJ python manage.py test ${@:3}"
        docker-compose run "$PROJ" python manage.py test "${@:3}"
        sleep 1
    fi
    exit 0
fi

# logs operation
# ./bin/project.sh <operation> <project> [params]
# ./bin/project.sh logs video
# ./bin/project.sh tail video
# ./bin/project.sh logs video -f tail=10
if [ "$OP" == "logs" ] || [ "$OP" == "tail" ]; then
    if [ "$PROJ" != "" ]; then
        if [ "$OP" == "logs" ]; then
            docker-compose logs $PROJ "${@:3}"
        fi
        if [ "$OP" == "tail" ]; then
            docker-compose logs $PROJ -f tail=10 "${@:3}"
        fi
    fi
    exit 0
fi

if [ -d "/src" ] && [ "$(which realpath)" == "/usr/bin/realpath" ]; then
    # inside of docker
    BASEDIR="$(realpath "$(dirname "${0}")")";
else
    # outside of docker run self to create project and app if name provided
    # ./bin/project.sh <operation> <project> [app] [port] [deps]
    # ./bin/project.sh create <project> [app] [port] [deps]
    if [ "$(docker ps | awk '{print $(NF)}' | grep "admin")" == "" ]; then
          echo "admin: CONTAINER NOT RUNNING"
          echo "docker-compose up -d admin"
          echo "$0 start admin"
          exit 1
      fi
    echo "1:  RUNNING docker-compose run admin /bin/bash \"/src/bin/project.sh\" $@"
    docker-compose run admin /bin/bash "/src/bin/project.sh" $@
    sleep 3
    if [ "$APP" != "" ]; then
        if [ -f ./bin/app.sh ]; then # check djangoposer exists
            # try to start project container
            if [ "$(docker ps | awk '{print $(NF)}' | grep "$PROJ")" == "" ]; then
                if [ "$(grep $PROJ: ./docker-compose.yml)" != "" ]; then
                    echo "2:  RUNNING docker-compose up -d "$PROJ" --remove-orphans"
                    docker-compose up -d "$PROJ" --remove-orphans
                    sleep 3
                fi
            fi
            echo "3:  RUNNING ./bin/app.sh create "$PROJ" "$APP" "$ENDPOINT" "$DEPS""
            ./bin/app.sh create "$PROJ" "$APP" "$ENDPOINT" "$DEPS"
            docker ps | grep "$PROJ"
        else
            echo "DJANGOPOSER ERROR: ./bin/app.sh SCRIPT NOT FOUND"
        fi
    else
        # last step, start project after creating
        if [ "$OP" == "create" ]; then
            echo "2:  RUNNING docker-compose up -d "$PROJ" --remove-orphans AFTER CREATE"
            docker-compose up -d "$PROJ" --remove-orphans
            sleep 1
        fi
    fi
    exit 0
fi

# continue only if inside docker, /src/ path translates to ./
if [ "$BASEDIR" != "/src/bin" ]; then
    exit 0
fi

if [ -d "/src/$PROJ" ] && [ -f "/src/$PROJ/Dockerfile" ] && [ -f "/src/$PROJ/requirements.txt" ]; then
    echo "PROJECT EXISTS $PROJ"
    exit 0
fi
if [ "$OP" == "create" ]; then
    if [ -d /src ]; then
        # step 1: create static and media directories inside project and touch requirements.txt
        if [ ! -d "/src/$PROJ" ]; then
            echo "--    CREATING PROJECT FOLDERS /src/$PROJ/{static/$PROJ,media}"
            mkdir -p /src/"$PROJ"/{"static/$PROJ","media"}
        fi
        echo "1:    CREATING $PROJ/requrements.txt having django djangorestframework django-extensions django-crispy-forms crispy-tailwind python-webpack-boilerplate psycopg2 pyyaml jq yq requests"
        echo "django djangorestframework django-extensions django-crispy-forms crispy-tailwind python-webpack-boilerplate psycopg2 celery pyyaml jq yq requests $DEPS" | xargs -n 1 > "/src/$PROJ/requirements.txt"

        # step 2: setup Dockerfile
        if [ ! -f "/src/$PROJ/Dockerfile" ]; then
            echo "2:    CREATING /src/$PROJ/Dockerfile"
            cat > "/src/$PROJ/Dockerfile" <<-EOM
FROM python:3
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
WORKDIR /src/$PROJ
COPY . .
RUN pip install -r requirements.txt

EOM
        fi
        # step 3: add project to docker-compose.yml file so docker-compose command works
        if [ ! -f "/src/docker-compose.yml" ]; then
            echo "!!! DJANGOPOSER ERROR: docker-compose.yml file is missing, please create it"
            exit 0
        else
            # check if entry exists in docker-compose.yml and add if doesn't
            if [ "$(grep $PROJ: /src/docker-compose.yml)" == "" ]; then
                echo "3:    ADDING $PROJ: to /src/docker-compose.yml"
                if [ "$PORT" == "auto" ] || [ "$PORT" == "" ]; then
                    _PORT="$(grep -n 'python manage.py runserver ' /src/docker-compose.yml | tail -n 1 | sed 's/:/ /g' | awk '{print $(NF)}')"
                    if [ "$_PORT" == "" ] || [ "$(( $_PORT + 0 ))" == "0" ]; then
                        # help $@
                        echo ""
                        echo "MISSING PORT"
                        echo "docker-compose.yml NOT UPDATED with $PROJ:"
                        exit 1
                    else
                        PORT="$(( $_PORT + 1 ))"
                    fi
                fi
                
                echo "- PORT: $PORT"
                LINE="$(grep -n dbnet: /src/docker-compose.yml | head -n1 | sed 's/:/ /' | awk '{print $1}')"
                head -n $(( $LINE - 2 )) "/src/docker-compose.yml" > /tmp/docker-compose.yml
                cat >> "/tmp/docker-compose.yml" <<-EOM
  $PROJ:
    container_name: $PROJ
    build: ./$PROJ/
    command: python manage.py runserver 0.0.0.0:$PORT
    working_dir: /src/$PROJ/
    volumes:
      - .:/src
      - ./$PROJ/static:/var/cache/$PROJ/static
    ports:
      - "$PORT:$PORT"
    env_file:
      - .env
    networks:
      - dbnet
    depends_on:
      - db
EOM
                tail -n +$(( $LINE - 1 )) "/src/docker-compose.yml" >> /tmp/docker-compose.yml
                mv /tmp/docker-compose.yml "/src/docker-compose.yml"
                $0 nginx "$PROJ" "$PORT"
            fi
        fi
        
        # step 4: grab the user model name to use in the settings.py to make imports of user model possible
        AUTH_USER_APP="$(grep "AUTH_USER_APP" /src/.env | sed 's/=/ /' | awk '{print $2}')"
        if [ "$AUTH_USER_APP" == "" ]; then
            AUTH_USER_APP="admin.users"
        fi
        AUTH_USER_MODEL="$(grep "AUTH_USER_MODEL" /src/.env | sed 's/=/ /' | awk '{print $2}')"
        if [ "$AUTH_USER_MODEL" == "" ]; then
            AUTH_USER_MODEL="users.AdminUser"
        fi
        echo "4:    USER MODEL"
        echo "  - AUTH_USER_APP = '$AUTH_USER_APP'"
        echo "  - AUTH_USER_MODEL = '$AUTH_USER_MODEL'"

        # step 5: create project using default django templates
        echo "5:    RUNNING django-admin startproject config /src/$PROJ"
        django-admin startproject config "/src/$PROJ"

        # step 6: inject location of prject into sys.path to make imports possible
        echo "6:    ADDING '/src' to sys.path in /src/$PROJ/manage.py"
        head -n 5 "/src/$PROJ/manage.py" > /tmp/manage.py
        echo -e "sys.path.insert(0, '/src')\n" >> /tmp/manage.py
        tail -n +7 "/src/$PROJ/manage.py" >> /tmp/manage.py
        mv /tmp/manage.py "/src/$PROJ/manage.py"

        # step 7: inject os module import statement
        echo "7:    ADDING import os in /src/$PROJ/config/settings.py"
        head -n 11 "/src/$PROJ/config/settings.py" > /tmp/settings.py
        echo -e "import os" >> /tmp/settings.py
        tail -n +13 "/src/$PROJ/config/settings.py" >> /tmp/settings.py
        mv /tmp/settings.py "/src/$PROJ/config/settings.py"

        # step 8: CHANGE ALLOWED_HOSTS
        echo "8:    CHANGING ALLOWED_HOSTS = ['*'] in /src/$PROJ/config/settings.py"
        LINE="$(grep -n "ALLOWED_HOSTS = " /src/$PROJ/config/settings.py | head -n1 | sed 's/:/ /' | awk '{print $1}')"
        head -n $(( $LINE - 1 )) "/src/$PROJ/config/settings.py" > /tmp/settings.py
        echo -e "ALLOWED_HOSTS = ['*']\n" >> /tmp/settings.py
        echo "ADDING: AUTH_USER_MODEL = '"$AUTH_USER_MODEL"' in /src/$PROJ/config/settings.py"
        echo -e '# App User Model\nAUTH_USER_MODEL = "'$AUTH_USER_MODEL'"' >> /tmp/settings.py
        tail -n +$(( $LINE + 1 )) "/src/$PROJ/config/settings.py" >> /tmp/settings.py
        mv /tmp/settings.py "/src/$PROJ/config/settings.py"

        # step 9: inject rest_framework and any other dependencies to INSTALLED_APPS
        echo "9:    ADDING 'rest_framework' and '$AUTH_USER_APP' to INSTALLED_APPS in /src/$PROJ/config/settings.py"
        LINE="$(grep -n "INSTALLED_APPS = " /src/$PROJ/config/settings.py | head -n1 | sed 's/:/ /' | awk '{print $1}')"
        head -n $(( $LINE + 6 )) "/src/$PROJ/config/settings.py" > /tmp/settings.py
        echo -e "\n    'rest_framework',\n\n    'django_extensions',\n    'crispy_forms',\n    'crispy_tailwind',\n    'webpack_boilerplate',\n\n    '"$AUTH_USER_APP"'," >> /tmp/settings.py
        tail -n +$(( $LINE + 7 )) "/src/$PROJ/config/settings.py" >> /tmp/settings.py
        mv /tmp/settings.py "/src/$PROJ/config/settings.py"
        
        # step 10: inject 'static' into TEMPLATES DIRS[]
        echo "10:    CHANGING 'DIRS': [], in /src/$PROJ/config/settings.py"
        LINE="$(grep -n "'DIRS': " /src/$PROJ/config/settings.py | head -n1 | sed 's/:/ /' | awk '{print $1}')"
        head -n $(( $LINE - 1 )) "/src/$PROJ/config/settings.py" > /tmp/settings.py
        echo -e "        'DIRS': [\n            'static',\n        ]," >> /tmp/settings.py
        tail -n +$(( $LINE + 1 )) "/src/$PROJ/config/settings.py" >> /tmp/settings.py
        mv /tmp/settings.py "/src/$PROJ/config/settings.py"

        # step 11: inject STATIC_URL STATICFILES_DIRS MEDIA_URL and MEDIA_ROOT
        echo "11a:   CHANGING STATIC_URL = '/static/' in /src/$PROJ/config/settings.py"
        LINE="$(grep -n "STATIC_URL = '/static/'" /src/$PROJ/config/settings.py | head -n1 | sed 's/:/ /' | awk '{print $1}')"
        head -n $(( $LINE - 1 )) "/src/$PROJ/config/settings.py" > /tmp/settings.py
        echo -e "STATIC_URL = '/$PROJ/static/'" >> /tmp/settings.py
        echo "11b:   ADDING STATICFILES_DIRS[] in /src/$PROJ/config/settings.py"
        echo -e "\nSTATICFILES_DIRS = [\n    'static/$PROJ/',\n]" >> /tmp/settings.py
        echo "11c:   ADDING MEDIA_URL and MEDIA_ROOT in /src/$PROJ/config/settings.py 33 33"
        echo -e "\nMEDIA_URL = '/$PROJ/media/'\nMEDIA_ROOT = os.path.join(BASE_DIR, 'media')" >> /tmp/settings.py
        tail -n +$(( $LINE + 1 )) "/src/$PROJ/config/settings.py" >> /tmp/settings.py
        mv /tmp/settings.py "/src/$PROJ/config/settings.py"

        # step 12: change database settings
        echo "12:    CHANGING DATABASES in /src/$PROJ/config/settings.py"
        LINE="$(grep -n 'DATABASES = ' /src/$PROJ/config/settings.py | head -n1 | sed 's/:/ /' | awk '{print $1}')"
        head -n $(( $LINE - 1 )) "/src/$PROJ/config/settings.py" > /tmp/settings.py
        echo -e "DATABASES = {" >> /tmp/settings.py
        echo -e "    'default': {" >> /tmp/settings.py
        echo -e "        'ENGINE': 'django.db.backends.postgresql'," >> /tmp/settings.py
        echo -e "        'NAME': os.environ.get('POSTGRES_NAME')," >> /tmp/settings.py
        echo -e "        'USER': os.environ.get('POSTGRES_USER')," >> /tmp/settings.py
        echo -e "        'PASSWORD': os.environ.get('POSTGRES_PASSWORD')," >> /tmp/settings.py
        echo -e "        'HOST': 'db' if 'POSTGRES_HOST' not in os.environ else os.environ.get('POSTGRES_HOST')," >> /tmp/settings.py
        echo -e "        'PORT': 5432 if 'POSTGRES_PORT' not in os.environ else int(os.environ.get('POSTGRES_PORT'))," >> /tmp/settings.py
        echo -e "    }" >> /tmp/settings.py
        echo -e "}" >> /tmp/settings.py
        tail -n +$(( $LINE + 10 )) "/src/$PROJ/config/settings.py" >> /tmp/settings.py
        mv /tmp/settings.py "/src/$PROJ/config/settings.py"

        echo "13:    ADDING FIXTURES_DIR in /src/$PROJ/config/settings.py"
        echo -e "\nFIXTURE_DIRS = (\n    os.path.join(BASE_DIR, 'fixtures'),\n)\n" >> "/src/$PROJ/config/settings.py"

        echo "14:    ADDING APPEND_SLASH = True in /src/$PROJ/config/settings.py"
        echo -e "\nAPPEND_SLASH = True\n" >> "/src/$PROJ/config/settings.py"

        if [ "$(grep $PROJ /src/projects.txt)" == "" ]; then
            echo "16:    ADDING $PROJ:$PORT to /src/project.txt"
            echo $PROJ:$PORT >> /src/projects.txt
        fi

        echo "15:    RUNNING $0 manage "$PROJ" collectstatic"
        $0 manage "$PROJ" collectstatic
    fi
    exit 0
fi
