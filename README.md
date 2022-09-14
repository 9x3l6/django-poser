# DJANGOPOSER 2022

A tool written in bash for optimizing your workflow when working on django micro-service oriented applications with a very opinionated structure for how things are organized

```shell
django-poser % ./bin/project.sh check     
db  | 2022-09-14 18:22:37.638 UTC [28] LOG:  database system was shut down at 2022-09-14 18:22:25 UTC
db  | 2022-09-14 18:22:37.685 UTC [1] LOG:  database system is ready to accept connections
admin  | Starting development server at http://0.0.0.0:8000/
admin  | Quit the server with CONTROL-C.
```

#### execute

```shell
django-poser % ./bin/project.sh fresh
```

#### output

```shell
[+] Running 2/2
 ⠿ Container db     Killed                                                                                                   0.2s
 ⠿ Container admin  Killed                                                                                                   0.3s
1:    RUNNING ./bin/project.sh build
RUNNING: docker-compose build --no-cache
[+] Building 47.7s (18/18) FINISHED                                                                                               
 => [django-poser_admin internal] load build definition from Dockerfile                                                      0.0s
 => => transferring dockerfile: 32B                                                                                          0.0s
 => [django-poser_web internal] load build definition from Dockerfile                                                        0.0s
 => => transferring dockerfile: 32B                                                                                          0.0s
 => [django-poser_admin internal] load .dockerignore                                                                         0.0s
 => => transferring context: 2B                                                                                              0.0s
 => [django-poser_web internal] load .dockerignore                                                                           0.0s
 => => transferring context: 2B                                                                                              0.0s
 => [django-poser_admin internal] load metadata for docker.io/library/python:3                                               1.2s
 => [django-poser_web internal] load metadata for docker.io/library/nginx:latest                                             0.0s
 => CACHED [django-poser_web 1/4] FROM docker.io/library/nginx:latest                                                        0.0s
 => [django-poser_web internal] load build context                                                                           0.0s
 => => transferring context: 242B                                                                                            0.0s
 => [django-poser_web 2/4] COPY ./nginx/nginx.conf /etc/nginx/conf.d/default.conf                                            0.1s
 => [django-poser_web 3/4] COPY ./nginx/locations.d /etc/nginx/locations.d                                                   0.1s
 => [django-poser_web 4/4] COPY ./nginx/upstreams.d /etc/nginx/upstreams.d                                                   0.0s
 => [django-poser_admin] exporting to image                                                                                  3.1s
 => => exporting layers                                                                                                      2.7s
 => => writing image sha256:f463107f59c9420046d5fec89f4e21857586f4cb97cb12e6121fa0056658c23c                                 0.3s
 => => naming to docker.io/library/django-poser_web                                                                          0.0s
 => => writing image sha256:7008ef12ed39d59acae0b8028e0f12ed11871d96b128bd45167aa4ad35d9c696                                 0.0s
 => => naming to docker.io/library/django-poser_admin                                                                        0.0s
 => [auth] library/python:pull token for registry-1.docker.io                                                                0.0s
 => [django-poser_admin 1/4] FROM docker.io/library/python:3@sha256:cbee3f15497620367b52b41daa976601c88a62063411ecd81c5855e  0.0s
 => => resolve docker.io/library/python:3@sha256:cbee3f15497620367b52b41daa976601c88a62063411ecd81c5855e05cc7df3b            0.0s
 => [django-poser_admin internal] load build context                                                                         0.0s
 => => transferring context: 698B                                                                                            0.0s
 => CACHED [django-poser_admin 2/4] WORKDIR /src/admin                                                                       0.0s
 => [django-poser_admin 3/4] COPY . .                                                                                        0.1s
 => [django-poser_admin 4/4] RUN pip install -r requirements.txt                                                            43.5s

Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
2:    RUNNING ./bin/project.sh start
RUNNING: docker-compose up -d --remove-orphans
[+] Running 3/3
 ⠿ Container db     Started                                                                                                  1.9s
 ⠿ Container admin  Started                                                                                                  4.0s
 ⠿ Container web    Started                                                                                                  1.4s
```


```shell
# or all of the steps below
./bin/project.sh kill
./bin/project.sh start
./bin/project.sh migrate auther
./bin/project.sh manage auther createsuperuser --username admin --email alex@goretoy.com
# or
./bin/project.sh manage auther loaddata users.yaml

./bin/project.sh migrate product
./bin/project.sh manage product loaddata products.yaml

./bin/project.sh test auther
./bin/project.sh test product

./bin/project.sh logs auther
./bin/project.sh logs product -f tail=10
```

## django-admin startproject

- make sure to start the `docker-compose up -d` or `./bin/project.sh start` before running command below because the create operation uses the admin container to create projects

```shell
# startproject
./bin/project.sh <operation> <project> [port] [app] [deps]
./bin/project.sh create project_name      # create project named project_name with port auto configured incremented
./bin/project.sh create project_name auto # same as above
./bin/project.sh create project_name 8080 # specify custom port number to use
./bin/project.sh create project_name auto app_name pandas numpy requests # runs startapp also after starting container

./bin/project.sh create account auto profiles auto pillow
./bin/project.sh create video auto videos api yt-dlp
./bin/project.sh create doc auto docs auto sphinx sphinxcontrib-packages django-sphinx-view
```

#### Manage project

```shell
./bin/project.sh manage project_name <params-to-manage.py>
```

#### Remove project

```shell
# remove or delete the project
./bin/project.sh <operation> <project>
./bin/project.sh remove project_name
```

#### Install Python dependencies

```shell
# install dependencies in project and update requirements.txt
./bin/project.sh install project_name <deps> # installs with pip3 and adds deps to project_name/requirements.txt
./bin/project.sh install project_name pandas numpy requests
```

#### Docker helper commands

```shell
./bin/project.sh check [num]   # run docker-compose logs on all projects to check things out
```

```shell
# docker specific commands
./bin/project.sh build project_name # runs docker-compose build --no-cache project_name

./bin/project.sh start project_name # start or restart docker containers for project; build and up -d

./bin/project.sh kill project_name # kill docker container

./bin/project.sh logs project_name
./bin/project.sh tail project_name
```

- If doing a fresh start and you see some `<project>` not starting, then run `logs <project>` to see why

### django-admin startapp

#### Create app inside project container

```shell
# startapp
./bin/app.sh <operation> <project> <app> [deps]
./bin/app.sh create project_name app_name pandas numpy requests   # create app inside project_name & install deps
```

#### Remove app from project

```shell
# remove or delete app from inside a project
./bin/app.sh <operation> <project> <app>
./bin/app.sh remove project_name app_name
```

# LICENSE

MIT License

Copyright (c) 2022 DjangoPoser ALEKSANDR GORETOY alex@goretoy.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
