# 制作 django_uwsgi_nginx一体的镜像
# 参考：https://blog.csdn.net/qq_36792209/article/details/82778611   https://blog.csdn.net/qq_31325495/article/details/88891525
# 预定义的目录 /data/apps/mysite /data/tmp/sock /data/tmp/pid /data/logs/uwsgi /data/logs/nginx

FROM alpine_py3_uwsgi_nginx:v1

MAINTAINER gdlmo <gytlgac@163.com>

# 设置用户
USER root

RUN mkdir -p /data/apps/mysite /data/tmp/sock /data/tmp/pid /data/logs/uwsgi /data/logs/nginx /data/logs/supervisor /etc/nginx/sites-available/default

WORKDIR /data/apps/mysite

COPY ./ ./

COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/mysite_nginx.conf /etc/nginx/sites-available/default 
COPY docker/supervisord.conf /etc/supervisor/conf.d/ 

RUN pip3 install  --default-timeout=100 --no-cache-dir -r /data/apps/mysite/requirements.txt -i https://pypi.douban.com/simple \	
	&& cp ./docker/uwsgi.ini ./

EXPOSE 80
# CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]