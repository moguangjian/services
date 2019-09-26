# 使用Docker 部署_ubuntu版

　　本文参考了网上的文章：

　　上周，我们完成了django、uwsgi、nginx在centos7上的部署，在部署中遇到了不少的问题，经过查找资料都一一解决了，为此还制作了一些安装脚本，但是如果再部署另一台服务器，我觉得遇到的问题还会不少，记得以前学习过Docker，如果我们制作好了镜像，那么无论我们部署多少台服务器，都会是一件非常简单的事，所以将我尝试制作Docker镜像的过程记录下来，因为通过制作镜像，发现制作好的Dockerfile基本只需要简单的修改python的版本，几乎满足所有的django应用。

　　Docker的基本应用和原理我另有文章记载，所以本文不再赘述，只记录配置的过程和相关的注意事项，以及制作好镜像所如何使用这个镜像。

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

### 三、制作Dockerfile前的一些准备工作

#### 3.1 准备ubuntu要使用的国内源

制作Docker镜像最大问题是，一小点错误我们都得要重来，如果没有使用国内源，这个过程就非常的漫长了。ubuntu 默认使用的是国外的源，在更新的时候会很慢，使用国内的源速度很快，如阿里源。在目录`/home/mysite/docker`下新建 sources.list 文件如下：

```shell
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
```

#### 3.2 准备pip要使用的国内源

原因同上。在目录`/home/mysite/docker`下新建 pip.conf 文件如下：

```ini
[global]
index-url = http://mirrors.aliyun.com/pypi/simple/
[install]
trusted-host = mirrors.aliyun.com
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

RUN mkdir -p /data/apps/mysite /data/tmp/sock /data/tmp/pid /data/logs/uwsgi /data/logs/nginx /data/logs/supervisor

WORKDIR /data/apps/mysite

COPY ./ ./

COPY docker/pip.conf /root/.pip/pip.conf

ADD docker/sources.list /etc/apt/sources.list
 
# Install required packages and remove the apt packages cache when done.

RUN apt-get update && \
    apt-get upgrade -y && \ 	
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