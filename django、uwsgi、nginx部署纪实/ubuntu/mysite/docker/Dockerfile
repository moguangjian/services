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
CMD ["supervisord", "-n"]# 基于ubuntu 16.04制作 django_uwsgi_nginx一体的镜像
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