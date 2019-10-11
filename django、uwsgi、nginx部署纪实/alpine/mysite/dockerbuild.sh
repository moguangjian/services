# !/bin/bash
filenames=('uwsgi.ini' 'Dockerfile' 'my_nginx.conf' )

# 获取项目名称
projectname=${PWD##*/}

# 修改对应的制作镜像所需要的文件，将mysite替换成项目名称
for filename in ${filenames[@]};do
    echo $filename
    if grep "mysite" ./docker/$filename >/dev/null 2>&1;then
        sed -i "s/mysite/$projectname/g" ./docker/$filename
    fi    
done

# 构建镜像
docker build -f ./docker/Dockerfile -t $projectname:v1 .

# 还原成原样以备其它项目引用
for filename in ${filenames[@]};do
    echo $filename
    if grep $projectname ./docker/$filename >/dev/null 2>&1;then
        sed -i "s/$projectname/mysite/g" ./docker/$filename
    fi    
done
