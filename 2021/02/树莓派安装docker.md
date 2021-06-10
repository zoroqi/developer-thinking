# 树莓派安装docker


## 安装

```
sudo curl -sSL https://get.docker.com | sh
```

## 相关配置


* 启动
```
sudo systemctl enable docker
sudo systemctl start docker
```

* 将用户添加到docker组

> 默认情况下，docker 命令会使用 Unix socket 与 Docker 引擎通讯。而只有 root 用户和 docker 组的用户才可以访问 Docker 引擎的 Unix socket

```
# 创建docker组
sudo groupadd docker
# 将当前用户加入 docker 组：
sudo usermod -aG docker $USER
```

* 镜像加速
在`/etc/docker/daemon.json`文件添加, 镜像源.
```
{
  "registry-mirrors": [
    "https://hub-mirror.c.163.com",
    "https://mirror.baidubce.com"
  ]
}
```

重启服务
```
sudo systemctl daemon-reload
sudo systemctl restart docker
```


## 学习参考

[Docker —— 从入门到实践](https://yeasy.gitbook.io/docker_practice/) [docker_practice](https://github.com/yeasy/docker_practice)

[树莓派上 Docker 的安装和使用](https://shumeipai.nxez.com/2019/05/20/how-to-install-docker-on-your-raspberry-pi.html)
