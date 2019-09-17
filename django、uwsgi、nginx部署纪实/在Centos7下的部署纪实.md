# 项目简介

　　本项目是单位上使用的一个政工提示系统的应用开发，基本django框架，使用mysql数据库，python3，并部署在centos7系统上，鉴于以前我开发过的系统的部署是使用了pythonanywhere的，所以本次部署中虽有共通之处，但还是遇到了许多问题，比如防火墙、selinux、uwsgi与nginx的部署与调用、如何设置能启动服务的方式等问题，有必要记录一个完整的部署过程，以备忘。

# 一、python3的安装

　　这没什么好讲的，网上类似的文章太多了，所以做了个脚本，如下：

```shell
#!/bin/bash
# 本脚本用于安装pytthon3 、uwsgi、nginx

# 更新源
yum install -y epel-release 
yum install -y https://centos7.iuscommunity.org/ius-release.rpm 
yum clean all 
yum makecache 
yum -y upgrade 

yum-builddep -y python 
yum install -y python36u  
yum install -y python36u-devel  
yum install -y python36u-pip      
rm -f /usr/bin/python  
rm -f /usr/bin/pip  
ln -s /bin/python3.6 /usr/bin/python 
ln -s /bin/pip3.6 /usr/bin/pip 
pip install --no-cache-dir --upgrade pip -i https://pypi.douban.com/simple  
if ! grep "python2" /usr/bin/yum  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/bin/yum
fi
if ! grep "python2" /usr/bin/yum-builddep  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/bin/yum-builddep
fi
if ! grep "python2" /usr/bin/yum-config-manager  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/bin/yum-config-manager
fi
if ! grep "python2" /usr/bin/yum-debug-dump  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/bin/yum-debug-dump
fi
if ! grep "python2" /usr/bin/yum-debug-restore  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/bin/yum-debug-restore
fi
if ! grep "python2" /usr/bin/yum-groups-manager  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/bin/yum-groups-manager
fi
if ! grep "python2" /usr/bin/yumdownloader  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/bin/yumdownloader
fi
if ! grep "python2" /usr/libexec/urlgrabber-ext-down  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/libexec/urlgrabber-ext-down
fi
# 防火墙的设置
if ! grep "python2" /usr/bin/firewall-cmd  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/bin/firewall-cmd
fi
if ! grep "python2" /usr/sbin/firewalld  >/dev/null 2>&1;then
    sed -i 's/python/python2.7/' /usr/sbin/firewalld
fi
```

# 安装mariadb

```shell
yum -y install mariadb mariadb-server
# 启动
systemctl start mariadb
# 设置开机启动
systemctl enable mariadb
#MariaDB的相关简单配置
mysql_secure_installation
#首先是设置密码，会提示先输入密码
Enter current password for root (enter for none):	#<–初次运行直接回车
#设置密码
Set root password? [Y/n] 	#<– 是否设置root用户密码，输入y并回车或直接回车
New password: 				#<– 设置root用户的密码
Re-enter new password: 		#<– 再输入一次你设置的密码

#其他配置
Remove anonymous users? [Y/n] 		#<– 是否删除匿名用户，回车
Disallow root login remotely? [Y/n] 	#<–是否禁止root远程登录,回车,
Remove test database and access to it? [Y/n] 	#<– 是否删除test数据库,回车
Reload privilege tables now? [Y/n] 				#<– 是否重新加载权限表，回车

#初始化MariaDB完成，接下来测试登录
mysql -uroot -ppassword
#完成。
```

## 二、配置MariaDB的字符集

- 文件`/etc/my.cnf`
   `vi /etc/my.cnf`
   在[mysqld]标签下添加

```csharp
init_connect='SET collation_connection = utf8_unicode_ci' 
init_connect='SET NAMES utf8' 
character-set-server=utf8 
collation-server=utf8_unicode_ci 
skip-character-set-client-handshake
```

- 文件`/etc/my.cnf.d/client.cnf`
   `vi /etc/my.cnf.d/client.cnf`
   在[client]中添加
   `default-character-set=utf8`
- 文件`/etc/my.cnf.d/mysql-clients.cnf`
   `vi /etc/my.cnf.d/mysql-clients.cnf`
   在[mysql]中添加
   `default-character-set=utf8`
- 全部配置完成，重启mariadb
   `systemctl restart mariadb`
- 之后进入MariaDB查看字符集
   `mysql> show variables like "%character%";show variables like "%collation%";`
   显示为

```ruby
+--------------------------+----------------------------+
| Variable_name            | Value                      |
+--------------------------+----------------------------+
| character_set_client    | utf8                      |
| character_set_connection | utf8                      |
| character_set_database  | utf8                      |
| character_set_filesystem | binary                    |
| character_set_results    | utf8                      |
| character_set_server    | utf8                      |
| character_set_system    | utf8                      |
| character_sets_dir      | /usr/share/mysql/charsets/ |
+--------------------------+----------------------------+
8 rows in set (0.00 sec)

+----------------------+-----------------+
| Variable_name        | Value          |
+----------------------+-----------------+
| collation_connection | utf8_unicode_ci |
| collation_database  | utf8_unicode_ci |
| collation_server    | utf8_unicode_ci |
+----------------------+-----------------+
3 rows in set (0.00 sec)
```

字符集配置完成。

注意: 这个时候,用其他服务器是不能登录数据库的,需要先设置权限，为了安全起见，我们创建我们的系统所要使用的数据库，并且创建对应的用户，该用户只具备管理该数据的权限。

## 创建数据库，添加用户，设置权限

```sql
CREATE USER 'zgxtuser'@'%' IDENTIFIED BY '你要设置的登录密码';
create database zgxt default character set utf8  COLLATE utf8_general_ci;
grant all on zgxt.* to 'zgxtuser'@'%'		-- % 表示可以从任意主机登录
```

**一个题外话：忘记mysql的登录密码怎么办？** 时间长了，我们没有记住当时设置的root用户密码，当登录时出现如下错误提示：

Mysql ERROR 1045 (28000): Access denied for user 'root'@'localhost'

这种问题需要强行重新修改密码，方法如下：
在Cent〇S7.0以及RHEL7.0使用此命令

```shell
 systemctl stop mariadb /usr/bin/mysqld_safe —skip-grant-tables
```
**<font color='red'>另外开个SSH连接或是另开一个shell</font>**

```shell
mysql
use mysql
update user set password=password("新的密码") where user='root' ;
flush privileges;
exit
```
使用
```shell
pkill -KILL -t pts/0
```
可将pts为0的**用户（之前运行 mysqld_safe的用户窗口）强制踢出

之后，正常启动 MySQL
```shell
 systemctl start mariadb
```

# 三、安装Virtualenv

```shell
yum install -y python-setuptools python-devel
pip install virtualenvwrapper

#编辑.bashrc文件
vim ~/.bashrc
#添加进去
export WORKON_HOME=$HOME/.virtualenvs		# 测试时我使用的是root用户登录，此时$HOME=/root
#sudo find / -name virtualenvwrapper.sh      查看你的virtualenvwrapper.sh在什么地方
source /usr/local/python3/bin/virtualenvwrapper.sh

#重新加载.bashrc文件
source ~/.bashrc

#虚拟环境保存的路径
cd ~/.virtualenvs/      （创建的虚拟环境都会保存在这个目录，前面设置的）

#创建指定python版本的虚拟环境方法
# find / -name python
mkvirtualenv -p /usr/bin/python zgxt
workon zgxt
# 安装django项目所需要的包
pip install -r requirements.txt

```

# 四、uwsgi

uwsgi是一个web服务器，也可以当做中间件。负责处理由nginx传递过来的动态请求。

## 4.1 安装

```shell
pip3 install uwsgi
ln -s /usr/local/python3/bin/uwsgi /usr/bin/uwsgi
```

## 4.2 测试uWSGI:

新建文件test.py，写入以下内容

```python
def application(env, start_response):
    start_response('200 OK',[('Content-Type', 'text/html')])
        #return ['Hello world'] # Python2
        return [b'Hello world'] # Python3[root@localhost pro]#
```

## 4.3、运行

```shell
sudo uwsgi --http 0.0.0.0:8000 --wsgi-file test.py
```

## 4.4 调试

如果**端口占用**，使用

```shell
lsof -i :80001
```

列出占用端口的程序的pid号，并使用以下命令杀掉所有占用端口的程序

```shell
sudo kill -9 pid
#如果使用pid文件
sudo uwsgi --stop uwsgi.pid
```

然后浏览 http://127.0.0.1:8000(或http://内网ip:8000、或http://外网ip:8000)查看效果，有”Hello World”输出即安装成功。

# 五、nginx的介绍与使用[^1]

### 5.1 Nginx的相关介绍

*Nginx* (engine x) 是一个高性能的[HTTP](https://baike.baidu.com/item/HTTP)和[反向代理](https://baike.baidu.com/item/反向代理/7793488)web服务器，同时也提供了IMAP/POP3/SMTP[服务](https://baike.baidu.com/item/服务/100571)。Nginx是由伊戈尔·赛索耶夫为[俄罗斯](https://baike.baidu.com/item/俄罗斯/125568)访问量第二的Rambler.ru站点（俄文：Рамблер）开发的，第一个公开版本0.1.0发布于2004年10月4日。

其将[源代码](https://baike.baidu.com/item/源代码)以类BSD许可证的形式发布，因它的稳定性、丰富的功能集、示例配置文件和低系统资源的消耗而[闻名](https://baike.baidu.com/item/闻名/2303308)。2011年6月1日，nginx 1.0.4发布。

Nginx是一款[轻量级](https://baike.baidu.com/item/轻量级/10002835)的[Web](https://baike.baidu.com/item/Web/150564) 服务器/[反向代理](https://baike.baidu.com/item/反向代理/7793488)服务器及[电子邮件](https://baike.baidu.com/item/电子邮件/111106)（IMAP/POP3）代理服务器，在BSD-like 协议下发行。其特点是占有内存少，[并发](https://baike.baidu.com/item/并发/11024806)能力强，事实上nginx的并发能力确实在同类型的网页服务器中表现较好，中国大陆使用nginx网站用户有：百度、[京东](https://baike.baidu.com/item/京东/210931)、[新浪](https://baike.baidu.com/item/新浪/125692)、[网易](https://baike.baidu.com/item/网易/185754)、[腾讯](https://baike.baidu.com/item/腾讯/112204)、[淘宝](https://baike.baidu.com/item/淘宝/145661)等[^2]。

#### 正向代理与反向代理

##### 正向代理

正向代理，意思是一个位于客户端和原始服务器(origin server)之间的服务器，为了从原始服务器取得内容，客户端向代理发送一个请求并指定目标(原始服务器)，然后代理向原始服务器转交请求并将获得的内容返回给客户端。客户端才能使用正向代理。

正向代理的用途：
（1）访问原来无法访问的资源，如Google
（2） 可以做缓存，加速访问资源
（3）对客户端访问授权，上网进行认证
（4）代理可以记录用户访问记录（上网行为管理），对外隐藏用户信息
<font color="red">正向代理最大的特点是客户端非常明确要访问的服务器地址；正向代理模式屏蔽或者隐藏了真实客户端信息。</font>![正向代理](assets/正向代理.png)

##### 反向代理

在[计算机网络](https://baike.baidu.com/item/计算机网络)中，**反向代理**是[代理服务器](https://baike.baidu.com/item/代理服务器/97996)的一种。服务器根据客户端的请求，从其关联的一组或多组后端[服务器](https://baike.baidu.com/item/服务器)（如[Web服务器](https://baike.baidu.com/item/Web服务器)）上获取资源，然后再将这些资源返回给客户端，客户端只会得知反向代理的IP地址，而不知道在代理服务器后面的服务器簇的存在。
![反向代理](assets/反向代理.png)

反向代理的特点：<font color="red">客户端是无感知代理的存在的，反向代理对外都是透明的，访问者并不知道自己访问的是一个代理。因为客户端不需要任何配置就可以访问。反向代理，"它代理的是服务端，代服务端接收请求"，</font>主要用于服务器集群分布式部署的情况下，反向代理隐藏了服务器的信息。

反向代理的作用：
（1）保证内网的安全，通常将反向代理作为公网访问地址，Web服务器是内网
（2）负载均衡，通过反向代理服务器来优化网站的负载

常见的项目场景![代理的常见场景](assets/代理的常见场景.png)

### 5.2、安装[^3]

本教程主要是基于CENTOS7，有两种安装方式，一是基于源码的安装方式，二是使用yum的安装方式，**两种方式安装后的一些目录会不太一样**，在使用时一定要注意。

#### 5.2.1 准备相关环境

在安装Nginx之前需要确保系统里已经安装好相关环境，包括gcc环境、pcre库（提供正则表达式和Rewrite模块的支持）、zlib库（提供Gzip压缩）、openssl库（提供ssl支持），使用yum直接安装这些依赖环境即可，不需要额外编译：

```shell
yum  install  gcc-c++ pcre  pcre-devel  openssl  openssl-devel  zlib  zlib-devel  -y
```

#### 5.2.2使用yum安装Nginx

nginx并不在centos的默认库中，需要添加epel扩展源

```shell
yum -y install epel-release		# 添加epel扩展源
yum install -y nginx
```

至此，nginx已经安装完毕，在命令行中输入Nginx，在浏览器中输入本机地址就能看到Nginx的欢迎界面了。

注意：**使用此方法安装的Nginx，它的配置文件目录是/etc/nginx/**

#### 5.2.3 使用源码安装Nginx

##### 5.2.3.1  为Nginx创建好用户和用户组

编译时会用上这个信息，后面启动服务时也会指定该用户

```shell
groupadd nginx
useradd -s /sbin/nologin -g nginx nginx
```

#### 5.2.3.2 下载源码并安装

```shell
cd /usr/local/src 
wget http://nginx.org/download/nginx-1.12.2.tar.gz
tar -zxvf nginx-1.12.2.tar.gz
cd nginx-1.12.2
./configure \
--prefix=/usr/local/nginx \
--user=nginx \
--group=nginx \
--sbin-path=/usr/local/nginx/sbin/nginx \
--conf-path=/usr/local/nginx/conf/nginx.conf \
--error-log-path=/usr/local/nginx/logs/error.log \
--http-log-path=/usr/local/nginx/logs/access.log \
--pid-path=/usr/local/nginx/nginx.pid \
--with-pcre \
--with-http_ssl_module \
--with-http_flv_module \
--with-http_mp4_module \
--with-http_gzip_static_module \
--with-http_stub_status_module
make && make install
```

##### 2.3.3 **Nginx编译安装常用选项解释：**

> --prefix=path：设置Nginx的安装路径，不写的话默认是在/usr/local/nginx
> --sbin-path=path：设置Nginx的可执行文件路径，默认路径是prefix/sbin/nginx
> --conf-path=path：设置Nginx配置文件路径，默认路径是prefix/conf/nginx.conf
> --pid-path=path：设置Nginx pid文件路径，默认路径是prefix/logs/nginx.pid
> --error-log-path=path：设置错误日志存放路径，默认路径是prefix/logs/error.log
> --http-log-path=path：设置访问日志存放路径，默认路径是prefix/logs/access.log
> --user=name：设置运行Nginx的用户，默认用户是nobody
> --group=name：设置运行Nginx的用户组，默认用户组是nobody
> --with-http_ssl_module：启用Nginx的SSL功能
> --with-http_realip_module：该模块可以记录原始客户端的IP而不是负载均衡的IP
> --with-http_sub_module：文字内容替换模块，可用于替换全站敏感字等
> --with-http_flv_module：开启对FLV格式文件的支持
> --with-http_mp4_module：开启对MP4格式文件的支持
> --with-http_gzip_module：提供对gzip压缩的支持
> --with-http_stub_status_module：开启Nginx状态监控模块
>
> --with-pcre：支持正则表达式

注：--with开头的选项通常是开启一些模块，而带有temp的选项一般是执行对应模块时产生的临时文件所存放的路径

注意：此方法安装的Nginx，**配置文件目录是/usr/local/nginx/conf/nginx.conf**

### 5.3、基本命令

```shell
/usr/local/nginx/sbin/nginx  -t  #检查配置文件是否有错
/usr/local/nginx/sbin/nginx  -v  #查看Nginx版本
/usr/local/nginx/sbin/nginx  -V  #查看Nginx安装时所用的编译选项，使用yum安装的也可以看到
/usr/local/nginx/sbin/nginx  -s  #发送信号，如stop、restart、reload、reopen
/usr/local/nginx/sbin/nginx  -c  #指定其他配置文件来启动nginx
```

conf：存放Nginx配置文件
logs：存放Nginx日志文件存放目录

### 5.4、配置

#### 5.4.1 语法

> Nginx的主配置文件由指令与指令块构成，**指令块以{ }大括号将多条指令组织在一起**
> **每条指令以；分号结尾**，指令与参数间用空格分隔
> **支持include语句组合多个配置文件**，提升可维护性
> #表示注释，$表示变量，部分指令的参数支持正则表达式

#### 5.4.2  在一台主机上配置多站点

##### 5.4.2.1 创建test.conf文件

因为我们是通过第三方源的方式进行安装，nginx的配置文件将会放入到/etc/nginx/目录下，我们可以在/etc/gninx/conf.d/这个目录下放置我们的站点配置文件，这样就可在一台主机上配置多站点，而且也便于管理。

```shell
cd /etc/nginx/conf.d/
mkdir vhosts
cd vhosts
vim zgxt.conf
```

下面是zgxt.conf的实际内容，注意：listen监听的端口不能冲突。

```shell
server { 
	listen *:8000;	#要监听的端口
	server_name www.zgxt.gygac;		#站点别名
	location / {
		root /home/www/zhenggongxitong;	# 站点文件目录
	}	
}
```

##### 5.4.2.2 修改/etc/nginx/nginx.conf文件

修改/etc/nginx/nginx.conf文件，在http配置项中将vhosts下的所有conf文件包含进去，如下所示：

![nginx.conf文件修改](assets/nginx.conf文件修改.png)

##### 5.4.2.3 修改站点目录的所有者及目录权限

这一步很关键，否则可能会出现 **“403 Forbidden“**的错误[^4]

首先，将nginx.config的user改为和启动用户一致，我们是以nginx用户及nginx用户组来运行的，所以nginx.conf配置如下:

![user](assets/user.png)

其次， 修改站点目录的所有者及权限

```shell
chown -R nginx:nginx /home/www/zhenggongxitong
chmod -R 755 /home/www/zhenggongxitong
curl localhost:8000	# 此时可以正确的访问站点了
```

最后，将我们的端口加入到防火墙中，这样我们才能进行正常的访问。

```shell
fiewall-cmd --permanent --zone=public --add-port=8000/tcp 		# 要加入的
firewall-cmd --reload
```

#### 4.3 安装uwsgi并进行配置

nginx只支持静态页面的访问，以及作为反向代理。因此，我们要使用python作为后台的编程语言需要将nginx做为反向代理来使用。以下是uwsgi的配置。

```ini
[uwsgi]

# Django-related settings
# the base directory (full path)
chdir           = /home/www/zhenggongxitong/
# Django's wsgi file
module          = zhenggongxitong.wsgi
# the virtualenv (full path)
#home            = /.virtualenv/map/
virtualenv = /root/.virtualenvs/zgxt/
# process-related settings
# master
master          = true
# maximum number of worker processes
processes       = 10
# the socket (use the full path to be safe
#socket          = /home/www/zhenggongxitong/site.sock
socket          = :8001
# ... with appropriate permissions - may be needed
chmod-socket    = 666
# clear environment on exit
vacuum          = true
```



##### 4.3.1安装（略）

##### 4.3.2 

```conf
upstream dtxt {         
    #server unix:////home/www/zhenggongxitong/site.sock;             
    server 127.0.0.1:8001;             
}
server {
    listen 8000 default_server;
    server_name www.zgxt.gygac;
    charset utf-8;

    client_max_body_size 75M;

    location / {
        include /etc/nginx/uwsgi_params;
        uwsgi_pass dtxt;
    }

    location /static {
        alias /home/www/zhenggongxitong/static;
    }
}
```

# 六、将uwsgi 与 nginx 作为服务开机启动

将uwsgi与nginx作为服务启动有很多方法，由于时间关系，没有更多的研究其它的方法，我只记录了其中一种

### 6.1 将uwsgi设置为服务

这里需要实现uwsgi的启动和停止，简单的处理方式可以直接在命令行中启动和kill掉uwsgi服务，但为了更安全、方便的管理uwsgi服务，配置uwsgi到systemd服务中，同时实现开启自启的功能；

#### 6.1.1创建配置文件

```shell
vim /etc/systemd/system/server_uwsgi.service
```

```ini
[Unit]
Description=HTTP Interface Server
After=syslog.target
 
[Service]
KillSignal=SIGQUIT
ExecStart=/bin/uwsgi --ini /home/www/zhenggongxitong/uwsgi.ini
Restart=always
Type=notify
NotifyAccess=all
StandardError=syslog
  
[Install]
WantedBy=multi-user.target
```

上面中ExecStart中的路径必需是绝对路径。

#### 6.1.2将该服务加入到systemd中

```shell
systemctl enable /etc/systemd/system/server_uwsgi.service
```

然后就可以通过systemctl来控制服务的启停

systemctl stop server_uwsgi.service      关闭uwsgi服务
systemctl start server_uwsgi.service     开启uwsgi服务
systemctl restart server_uwsgi.service   重启uwsgi服务

注意事项：

```
如果uwsgi配置文件中配置了 daemonize=/path/uwsgi.log (uwsgi服务以守护进程运行)
会导致sytemctl启动时多次重启而导致启动失败
需改为 logto=/path/uwsgi.log
```

### 6.2 nginx设置为启动

```shell
systemctl enable nginx
```

# 七、常见问题

### 7.1 启动nginx失败

启动nginx的服务失败，查看nginx的错误日志，出现如下错误提示：

> Starting nginx: nginx: [emerg] bind() to 0.0.0.0:8091 failed (13: Permission denied)[^5]

权限被拒绝，开始以为是端口被别的程序占用了，查看活动端口然而没有程序使用此端口，网上搜索说是需要权限的问题，但是我在测试时直接在命令行输入`nginx`，运行是正常的，说明应该不是目录的权限问题，而且我在设置nginx的配置文件时，使用了nginx用户及用户组，并将目录的所有者有权限都设置成了nginx，但将nginx作为服务时，一但重启就出现错误，这就挺郁闷的,后来还是给力的google给了答案，是因为selinux默认只允许80,81,443,8008,8009,8443,9000用作HTTP端口使用

要查看selinux允许的http端口必须使用semanage命令，下面首先安装semanage命令工具

在安装semanage工具之前，我们先安装一个tab键补齐二级命令功能工具bash-completion：

```shell
yum -y install bash-completion
yum -y install policycoreutils-python.x86_64
```

现在终于可以使用semanage了，我们先查看下http允许访问的端口：

```shell
semanage port -l | grep http_port_t
```

> semanage port -l | grep http_port_t
>
> http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000

然后我们将需要使用的端口8000加入到端口列表中：

```shell
 semanage port -a -t http_port_t -p tcp 8000
```

> semanage port -l | grep http_port_t
>
> http_port_t                    tcp      8000, 80, 81, 443, 488, 8008, 8009, 8443, 9000

好了现在nginx可以使用8000端口了

selinux的日志在/var/log/audit/audit.log

但此文件记录的信息不够明显，很难看出来，我们可以借助audit2why和audit2allow工具查看，这两个工具也是policycoreutils-python软件包提供的。

```shell
audit2why < /var/log/audit/audit.log
```

收集selinux工具的日志，还有另外一个工具setroubleshoot，对应的软件包为setroubleshoot-server

### 7.2 SElinux错误：ValueError：已定义端口tcp / 8000[^6]

我一直在尝试在端口8000上为SELinux添加一个异常，因为我使用了命令：

```shell
 semanage port -a -t http_port_t -p tcp 5000
```

但是返回错误:

> ValueError: Port tcp/8000 already defined

我尝试使用以下命令检查是否是这样：

```shell
semanage port -l |grep 8000
```

给出了输出，

> http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000

如您所见，8000不在列表中。

我有什么明显的遗失吗？

所以我发现另一个服务已经为TCP端口8000定义了状态。

但是通过用`-a`替换`-m`选项进行修改，将tcp port 8000添加到`http_port_t`

所以有效的命令是：

```shell
semanage port -m -t http_port_t -p tcp 8000
```

### 7.3 centos 7上nginx 报错，open() "style.css" failed (13: Permission denied)

前两天部署好后，我测试一直正常的，今天有同事说网页显示不正常，css文件无法获取，发现web打开没有找到静态文件，nginx日志报permission denied, 检查过程如下：

#### 7.3.1 检查/home/www/zhenggongxitong/static目录的属主和权限

```shell 
chown -R nginx:nginx /home/www/zhenggongxitong
```

属主和用户组均为nginx(上文中已做了修改)(nginx worker以nginx用户启动)，权限正确

没办法，google，发现stackoverflow如下回答:

> 24  I've just had the same problem on a CentOS 7 box.
> Seems I'd hit selinux. Putting selinux into permissive mode (setenforce permissive) has worked round the problem for now. I'll try and get back with a proper fix.

在命令行执行指令setenforce permissive(宽容模式：代表 SELinux 运作中，不过仅会有警告讯息并不会实际限制 domain/type 的存取。这种模式可以运来作为 SELinux 的 debug 之用；)后刷新恢复。

这种办法只是把selinux的安全级别降低了。

经过不停的google+各种关键词，终于找到彻底解决办法：

#### 7.3.2 安装audit.log的相关分析工具集

```shell
yum install setroubleshoot
```

#### 7.3.3 产生可访问的白名单

```shell
cat /var/log/audit/audit.log| grep nginx |audit2allow -M mynginx
```

#### 7.3.4 使白名单生效

```shell
semodule -i mynginx.pp
#恢复selinux默认功能
setenforce enforcing
```


再次刷新页面，静态文件正常，问题解决

附上selinux的介绍：

SELinux(Security-Enhanced Linux) 是美国国家安全局（NSA）对于强制访问控制的实现，是 Linux历史上最杰出的新安全子系统。NSA是在Linux社区的帮助下开发了一种访问控制体系，在这种访问控制体系的限制下，进程只能访问那些在他的任务中所需要文件。



[^1]:  [Nginx 相关介绍(Nginx是什么?能干嘛?)](https://www.cnblogs.com/wcwnina/p/8728391.html)
[^2]:  [nginx](https://baike.baidu.com/item/nginx/3817705?fr=aladdin)
[^3]:[【Nginx配置教程】Nginx-1.13.10编译安装与配置教程](http://www.linuxe.cn/post-168.html)
[^4]:	[Nginx 出现 403 Forbidden 最终解决方法](https://www.jb51.net/article/121064.htm)
[^5]: [重启Nginx出现bind() to 0.0.0.0:8088 failed (13: Permission denied)](https://www.linuxidc.com/Linux/2019-02/157121.htm)
[^6]: [SElinux错误：ValueError：已定义端口tcp / 5000](http://www.kbase101.com/question/35273.html)

[Nginx 安装与部署配置以及Nginx和uWSGI开机自启](https://www.cnblogs.com/wcwnina/p/8728430.html)