# 使用Docker 部署

　　上周，我们完成了django、uwsgi、nginx在centos7上的部署，在部署中遇到了不少的问题，经过查找资料都一一解决了，为此还制作了一些安装脚本，但是如果再部署另一台服务器，我觉得遇到的问题还会不少，记得以前学习过Docker，如果我们制作好了镜像，那么无论我们部署多少台服务器，都会是一件非常简单的事，所以将我尝试制作Docker镜像的过程记录下来，因为通过制作镜像，发现制作好的Dockerfile基本只需要简单的修改python的版本，几乎满足所有的django应用。

　　Docker的基本应用和原理我另有文章记载，所以本文不再赘述，只记录配置的过程和相关的注意事项，以及制作好镜像所如何使用这个镜像。

### 一、环境介绍

#### 1、宿主机 

系统：centos7 64位
dockerfile所在目录：/home/django_uwsgi_nginx
django项目所在目录：/home/www
项目名称：zhenggongxitong(所以项目代码的全路径是/home/www/zhenggongxitong)

#### 2、docker镜像工作目录

镜像的工作目录：/www/apply

### 二、准备nginx 文件

```shell
vim /home/django_uwsgi_nginx/nginx.conf
```

下面是nginx.conf的文件内容

```ini
  1 # For more information on configuration, see:
  2 #   * Official English Documentation: http://nginx.org/en/docs/
  3 #   * Official Russian Documentation: http://nginx.org/ru/docs/
  4
  5 user nginx;
  6 worker_processes auto;
  7 error_log /var/log/nginx/error.log;
  8 pid /run/nginx.pid;
  9
 10 # Load dynamic modules. See /usr/share/nginx/README.dynamic.
 11 include /usr/share/nginx/modules/*.conf;
 12
 13 events {
 14     worker_connections 1024;
 15 }
 16
 17 http {
 18     log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
 19                       '$status $body_bytes_sent "$http_referer" '
 20                       '"$http_user_agent" "$http_x_forwarded_for"';
 21
 22     access_log  /var/log/nginx/access.log  main;
 23
 24     sendfile            on;
 25     tcp_nopush          on;
 26     tcp_nodelay         on;
 27     keepalive_timeout   65;
 28     types_hash_max_size 2048;
 29
 30     include             /etc/nginx/mime.types;
 31     default_type        application/octet-stream;
 32
 33     # Load modular configuration files from the /etc/nginx/conf.d directory.
 34     # See http://nginx.org/en/docs/ngx_core_module.html#include
 35     # for more information.
 36     include /etc/nginx/conf.d/*.conf;
 37     include /etc/nginx/conf.d/vhosts/*.conf;
 38     upstream webapp {         #--该段添加在server{}外面，http{}里面
 39         # server unix:////www/apply/zhenggongxitong/site.sock;    # 以socket文件的方式监听
 40         server 127.0.0.1:8001;      #--uwsgi3服务器和监听的端口
 41     }
 42     server {
 43         listen       80 default_server;
 44         listen       [::]:80 default_server;
 45         server_name  zgxt.vm.gygac;
 46         charset utf-8;
 47
 48         client_max_body_size 75M;
 49
 50         root         /usr/share/nginx/html;
 51
 52         # Load configuration files for the default server block.
 53         include /etc/nginx/default.d/*.conf;
 54
 55         location / {
 56             include /etc/nginx/uwsgi_params;
 57             uwsgi_pass webapp;
 58         }
 59
 60         location /static {
 61             alias /www/apply/zhenggongxitong/static;
 62         }
 63
 64         error_page 404 /404.html;
 65             location = /40x.html {
 66         }
 67
 68         error_page 500 502 503 504 /50x.html;
 69             location = /50x.html {
 70         }
 71     }
 72
 73 # Settings for a TLS enabled server.
 74 #
 75 #    server {
 76 #        listen       443 ssl http2 default_server;
 77 #        listen       [::]:443 ssl http2 default_server;
 78 #        server_name  _;
 79 #        root         /usr/share/nginx/html;
 80 #
 81 #        ssl_certificate "/etc/pki/nginx/server.crt";
 82 #        ssl_certificate_key "/etc/pki/nginx/private/server.key";
 83 #        ssl_session_cache shared:SSL:1m;
 84 #        ssl_session_timeout  10m;
 85 #        ssl_ciphers HIGH:!aNULL:!MD5;
 86 #        ssl_prefer_server_ciphers on;
 87 #
 88 #        # Load configuration files for the default server block.
 89 #        include /etc/nginx/default.d/*.conf;
 90 #
 91 #        location / {
 92 #        }
 93 #
 94 #        error_page 404 /404.html;
 95 #            location = /40x.html {
 96 #        }
 97 #
 98 #        error_page 500 502 503 504 /50x.html;
 99 #            location = /50x.html {
100 #        }
101 #    }
102
103 }

```

<font color="red">注意：</font>

- 第40行，本来使用sock套接字文件性能应该更高，只是为了方便使用了端口的方式
- 第60行，/static目录的设置，我还没有想到更好的办法



### 二、准备Dokcerfile文件

```shell
vim /home/django_uwsgi_nginx/Dockerfile
```

以下是Dockerfile文件内容

```shell
FROM centos:7
#作者
MAINTAINER gdlmo <gytlgac@163.com>
#对外的端口
EXPOSE 80

RUN /usr/bin/mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup && \
    /usr/bin/curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo && \
    yum install -y epel-release && \
    yum install -y https://centos7.iuscommunity.org/ius-release.rpm && \
    yum clean all && \
    yum makecache && \
    yum -y upgrade && \
    yum -y install kde-l10n-Chinese && \
    yum -y reinstall glibc-common && \
    yum clean all && \
    localedef -c -f UTF-8 -i zh_CN zh_CN.utf8    
ENV LC_ALL "zh_CN.UTF-8"

# 设置语言为中文
ENV LANG C.UTF-8
# 设置时区
RUN /usr/bin/cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo 'Asia/Shanghai' >/etc/timezone

RUN echo -e "\033[31m   开始安装python uwsgi nginx.....\033[0m "
# 下面是安装python3 django2.1.8 uwsgi nginx
COPY ./requirements.txt /www/apply/
COPY ./uwsgi.ini /www/apply/
COPY ./nginx.conf /www/apply/
COPY ./start.sh /www/apply/

RUN yum install -y mysql-devel && \
    yum-builddep -y python && \
    yum install -y python36u  && \
    yum install -y python36u-devel  && \
    yum install -y python36u-pip  && \    
    rm -f /usr/bin/python  && \
    rm -f /usr/bin/pip  && \
    ln -s /bin/python3.6 /usr/bin/python && \
    ln -s /bin/pip3.6 /usr/bin/pip && \
    pip install --no-cache-dir --upgrade pip -i https://pypi.douban.com/simple  && \
    sed -i 's/python/python2.7/' /usr/bin/yum  && \
    sed -i 's/python/python2.7/' /usr/bin/yum-builddep  && \
    sed -i 's/python/python2.7/' /usr/bin/yum-config-manager && \
    sed -i 's/python/python2.7/' /usr/bin/yum-debug-dump && \
    sed -i 's/python/python2.7/' /usr/bin/yum-debug-restore && \
    sed -i 's/python/python2.7/' /usr/bin/yum-groups-manager && \
    sed -i 's/python/python2.7/' /usr/bin/yumdownloader && \
    sed -i 's/python/python2.7/' /usr/libexec/urlgrabber-ext-down && \
    pip install --no-cache-dir uwsgi -i https://pypi.douban.com/simple  && \
    pip install --no-cache-dir -r /www/apply/requirements.txt -i https://pypi.douban.com/simple  && \
    yum install nginx -y && \
    yum clean all && \
    cp -f /www/apply/nginx.conf /etc/nginx/
```



参考文章：

[docker 生成 django + uwsgi + nginx + supervisor 镜像](https://blog.csdn.net/qq_31325495/article/details/88891525)

[django上线部署-uwsgi+nginx+py3/django1.10](https://www.cnblogs.com/iiiiiher/p/8258903.html)

[docker入门，如何部署Django uwsgi nginx应用](https://www.imooc.com/article/23052)

[使用Docker搭建Django，Nginx，R，Python部署环境的方法](https://www.jb51.net/article/134884.htm)