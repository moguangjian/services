# 使用Docker 部署之进阶_alpine版

　　本文参考了网上的文章：[项目部署：docker-django-nginx-uwsgi-postgres-supervisor](https://blog.csdn.net/qq_36792209/article/details/82778611)、[**django-uwsgi-nginx**](https://github.com/dockerfiles/django-uwsgi-nginx)、[alpine-python3-django-uwsgi-nginx ](https://github.com/Koff/alpine-python3-django-uwsgi-nginx)、[Docker构建nginx+uwsgi+flask镜像（一）](https://www.cnblogs.com/beiluowuzheng/p/10219506.html)、[Docker从alpine构建python3+Django+uwsgi+twisted+Pillow+mysql](https://www.jianshu.com/p/6fa94d6222d2)、[docker-alpine-python3-selenium](https://www.jianshu.com/p/59034b414a5e)

　　前面，我们完成了使用ubuntu的镜像完成了部署的工作（《使用Docker进行部署_ubuntu1804》），但是，在部署中我发现存在几个问题：一、生成的镜像比较大，有600多M，所以这次我们采用体积更小的apline镜像作为基础镜像; 二、生成的过程非常慢，一小点改动要重新生成镜像会非常的耗时。在这篇文章中我们将主要解决上述的问题，并做一些测试与改动，如将代码和日志都放在宿主机上，通过卷映射的方式来使用，这样我们在开发时修改代码就不必每次重新生成镜像了。

　　还是按上一篇文章的方式，进行一些铺垫。

### 一、环境介绍

#### 1、宿主机 

> 系统：centos7 64位
> django 项目在宿主机中目录：/home/mysite
> dockerfile所在的目录：/home/mysite/docker

项目名称：mysite(所以项目代码的全路径是/home/mysite)

#### 2、docker容器工作目录

容器的工作目录：

/data/apps/mysite 
/data/tmp/sock 
/data/tmp/pid 
/data/logs/uwsgi 
/data/logs/nginx

#### 4、项目及Dockerfile文件目录树展示

```shell
[root@localhost mysite]# pwd
/home/mysite
[root@localhost mysite]# tree -L 2
.
├── db.sqlite3
├── docker
│   ├── Dockerfile
│   ├── Dockerfile_bak
│   ├── mysite_nginx.conf
│   ├── pip.conf
│   ├── sources.list
│   ├── supervisord.conf
│   └── uwsgi.ini
├── manage.py
├── mysite
│   ├── __init__.py
│   ├── __pycache__
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── requirements.txt
├── static
│   └── admin
└── todo.md

```



### 二、准备项目文件

在Docker封装之前，在/home目录

##### 2.1 创建项目

```shell
pip install django
cd /home/
django-admin startproject mysite
cd mysite
```

> ##### 关于项目目录
>
> manage.py 文件所在位置为项目目录，如本文中的`/home/mysite/`。

##### 2.2 部署静态文件及配置数据库

###### 2.2.1 修改settings.py文件

修改 /home/mysite/mysite文件夹下 settings.py 文件中的ALLOWED_HOSTS配置项，不修改该值的话在启动django项目时会报错DisallowedHost at / Invalid HTTP_HOST ...

```python
ALLOWED_HOSTS = ['*', 'ip'] # ip为你所使用的IP，可自行修改, `*`代表允许所有的ip
```

###### 2.2.2 收集态文件集中到static文件夹中

在运行nginx之前，要把Django的静态文件集中到static文件夹中。在 /home/mysite/mysite/settings.py文件末尾加入:

```python
STATIC_ROOT = os.path.join(BASE_DIR, "static/")
```

在项目目录下：

```shell
cd /home/mysite
python manage.py collectstatic
```

###### 2.2.3 配置数据库

```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',
        'NAME': "你的数据库名",
        'USER': "数据库账户",
        'PASSWORD': "登录密码",
        'HOST': "192.168.XXX.XXX",
        'PORT': "3306",
    }
}
```

### 三、制作基础镜像

　　在制作的过程中我发现，其实我们可以将python3、uwsgi、nginx制作成一个基础镜像，将我们要使用的django、要要使用的python包及我们的配置文件放到第二个镜像中制作，这样会大大的加速我们的制作速度，为了减少镜像的大小，我们采用了alpine:latest镜像作为基础镜像。下面是我们制作python3、uwsgi、nginx基础镜像的Dockerfile文件：

```shell
# 配置基础镜像
FROM alpine:latest

# 添加标签说明
LABEL author="mgj" email="gztf@21cn.com"  purpose="python3 uwsgi nginx supervisor in a image"

# 配置清华镜像地址
RUN echo "https://mirror.tuna.tsinghua.edu.cn/alpine/v3.8/main/" > /etc/apk/repositories

# 设置用户
USER root

# 设置时区变量
ENV TIME_ZONE Asia/Shanghai

#安装时区包并配置时区TIME_ZONE为中国标准时间
RUN apk add --no-cache -U tzdata \
    && ln -sf /usr/share/zoneinfo/${TIME_ZONE} /etc/localtime \ 
    && echo "${TIME_ZONE}" > /etc/timezone 

# 更新升级软件
RUN apk add --update --upgrade \
    vim    

# 安装软件python3,升级pip,setuptools,安装nginx supervisor uwsgi
RUN apk add --no-cache python3 gcc make libc-dev linux-headers pcre-dev jpeg-dev zlib-dev mariadb-dev libffi-dev python3-dev nginx supervisor \    
    && python3 -m ensurepip \
    && rm -r /usr/lib/python*/ensurepip \
    && pip3 install --default-timeout=100 --no-cache-dir --upgrade pip -i https://pypi.douban.com/simple \
    && pip3 install --default-timeout=100 --no-cache-dir --upgrade setuptools -i https://pypi.douban.com/simple \
    && pip3 install --default-timeout=100 --no-cache-dir --upgrade uwsgi -i https://pypi.douban.com/simple \
    && if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip ; fi \
    && if [[ ! -e /usr/bin/python ]]; then ln -sf /usr/bin/python3 /usr/bin/python; fi \
    && rm -rf /var/cache/apk/* \
    && rm -rf ~/.cache/pip


# 设置启动点 镜像启动时的第一个命令, 通常 docker run 的参数不会覆盖掉该指令
ENTRYPOINT [ "/bin/sh" ]

# 配置非生效对外端口
EXPOSE 80

# 设置启动时预期的命令参数, 可以被 docker run 的参数覆盖掉.
# CMD [ "/bin/sh" ]
```

<font color='red'>**注意：**</font> 有几个包是需要安装的，分别是`jpeg-dev zlib-dev mariadb-dev libffi-dev`,如果不安装，在安装django及mysql所需要的包时会出错。

```shell
docker build -t alpine_py3_uwsgi_nginx:v1 .
```

### 四、准备制作镜像的文件

#### 4.1 准备uwsgi.ini文件

在目录`/home/mysite/docker`中新建uwsgi.ini文件，内容如下：

```ini
# uwsgi.ini file
[uwsgi]

# Django-related settings
# the base directory (full path)
chdir           = /data/apps/mysite
# Django's wsgi file
module          =  mysite.wsgi:application

# the virtualenv (full path)，使用docker不需要使用虚拟环境了
#home            = /usr/src/app
# process-related settings
# master
master          = true
# maximum number of worker processes
processes       = 4
# the socket (use the full path to be safe
socket          = /data/tmp/sock/mysite.sock

pidfile 		= /data/tmp/pid/mysite.pid
# ... with appropriate permissions - may be needed
chmod-socket    = 666
# clear environment on exit
vacuum          = true

```

**注意**：chdir与module的配置项一定要写对，并且 socket配置项一定要与nginx中的一致。

#### 4.2准备nginx 文件

在目录`/home/mysite/docker`中新建mysite_nginx.conf文件，内容如下：

```ini
# mysite_nginx.conf

# the upstream component nginx needs to connect to
upstream mysite {
    # server unix:///path/to/your/mysite/mysite.sock; # for a file socket
    #server 127.0.0.1:8001; # for a web port socket (we'll use this first)
    server unix:///data/tmp/sock/mysite.sock;       # 必需与uwsgi.ini中定义的一致
}
# configuration of the server
server {
    # the port your site will be served on
    listen      80 default_server;
    # the domain name it will serve for
    server_name localhost; # substitute your machine's IP address or FQDN
    charset     utf-8;

    # max upload size
    client_max_body_size 75M;   # adjust to taste

#   Django media
#    location /media  {
#       alias /path/to/your/mysite/media;  # 你的 Django 项目media files路径 - amend as required
#   }

   location /static {
       alias /data/apps/mysite/static; # 你的 Django 项目 static files路径 - amend as required
   }

    # Finally, send all non-media requests to the Django server.
    location / {
        uwsgi_pass  mysite;
        include     /etc/nginx/uwsgi_params; # the uwsgi_params file you installed
    }
}

```

**注意**：

- socket要与uwsgi.ini中定义的一致
- /static的路径要全路径
- 因为要作为 default_server，所以这个文件在容器中是copy到`/etc/nginx/sites-available/default`目录中的

#### 4.3 准备supervisord.conf文件

在目录`/home/mysite/docker`中新建supervisord.conf文件，内容如下：

```ini
[program:app-uwsgi]
command = /usr/local/bin/uwsgi --ini /data/apps/mysite/docker/uwsgi.ini

[program:nginx-app]
command = /usr/sbin/nginx

```

#### 4.4 制作Dockerfile文件

在目录`/home/mysite/docker`中新建Dockerfile文件，内容如下：

```shell
# 基于ubuntu 18.04制作 django_uwsgi_nginx一体的镜像
# 参考：https://blog.csdn.net/qq_36792209/article/details/82778611   https://blog.csdn.net/qq_31325495/article/details/88891525
# 预定义的目录 /data/apps/mysite /data/tmp/sock /data/tmp/pid /data/logs/uwsgi /data/logs/nginx

FROM ubuntu:18.04

MAINTAINER gdlmo <gytlgac@163.com>

ENV LANG C.UTF-8
# 设置时区
ENV TZ=Asia/Shanghai

RUN mkdir -p /data/apps/mysite /data/tmp/sock /data/tmp/pid /data/logs/uwsgi /data/logs/nginx /data/logs/supervisor

WORKDIR /data/apps/mysite

COPY ./ ./

COPY docker/pip.conf /root/.pip/pip.conf

ADD docker/sources.list /etc/apt/sources.list
 
# Install required packages and remove the apt packages cache when done.

RUN apt-get update && \
    apt-get upgrade -y && \ 	
    ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone && \
    apt-get install tzdata && \
    apt-get install -y \
    libmysqlclient-dev \
	vim \
	python3 \
	python3-dev \
	python3-setuptools \
	python3-pip \
	nginx \
	supervisor \
	sqlite3 && \
	pip3 install -U pip && \
   rm -rf /var/lib/apt/lists/*

WORKDIR /data

# install uwsgi now because it takes a little while
RUN pip3 install uwsgi

# setup all the configfiles
RUN echo "daemon off;" >> /etc/nginx/nginx.conf
# COPY nginx-app.conf /etc/nginx/sites-available/default
# COPY supervisor-app.conf /etc/supervisor/conf.d/
COPY docker/mysite_nginx.conf /etc/nginx/sites-available/default 
COPY docker/supervisord.conf /etc/supervisor/conf.d/ 

# COPY requirements.txt and RUN pip install BEFORE adding the rest of your code, this will cause Docker's caching mechanism
# to prevent re-installing (all your) dependencies when you made a change a line or two in your app.

# COPY app/requirements.txt /home/docker/code/app/
RUN pip3 install -r /data/apps/mysite/requirements.txt

# add (the rest of) our code
# COPY . /home/docker/code/

# install django, normally you would remove this step because your project would already
# be installed in the code/app/ directory
#RUN django-admin.py startproject website /home/docker/code/app/

EXPOSE 80
CMD ["supervisord", "-n"]

```

**注意**

- 基础镜像是ubuntu 18.04
- 

### 五、开始制作

#### 5.1执行制作命令

在项目目录下`/home/mysite`执行命令，而不是在Dockerfile文件所在的目录（`/home/mysite/docker`）

```shell
cd /home/mysite
docker build -f docker/Dockerfile -t django:v1 .

```

　　为什么要在项目目录下执行呢，我个人的习惯是将与项目有关的资料、执行脚本等都放到项目目录下，以便后期通过项目就可以知道项目期间还做了哪些工作，所以将制作镜像的Dockerfile放到了项目的docker目录下，如果是在Dockerfile所在的目录执行build命令，会出现一个错误：Forbidden path outside the build context  ..[^1]

#### 5.2 运行容器

```shell
docker run --name webapp -d -p 8080:80 django:v1  # 8080是你宿主机对外提供的端口，防火墙要放行

```

通过浏览器就可以看到熟悉的界面了

![django启动](使用Docker进行部署_ubuntu1804.assets/django启动.png)





[^1]: [docker 创建镜像时显示 Forbidden path outside the build context](https://www.cnblogs.com/saving/p/10401723.html)