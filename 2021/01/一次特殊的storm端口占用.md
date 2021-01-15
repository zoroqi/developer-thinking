# 一次特殊的storm端口占用

storm任务迁移, 老集群下线迁移到新集群, 出现一个诡异的问题, 任务死活起不来总是卡主, 卡在链接其他worker上, 也没细看直接截图给了运维让运维解决, 心想新集群可能没搭建好运维可以解决就可以了.

运维给的方案是不停的调试zk的配置, 以为是zk配置不对, 发现咋调都不好使. 之后运维要了发布权限, 运维启动立刻就好了. 搞得我很郁闷, 我以为运维应该是改好了. 也就没有继续查, 之后需求调整发现我还是无法发布, 只能认真开始看日志和分析问题了.

报错内容

```
o.a.s.u.StormBoundedExponentialBackoffRetry client-boss-1 [WARN] WILL SLEEP FOR 700ms (MAX)
o.a.s.m.n.Client client-boss-1 [ERROR] connection attempt 180 to Nett ip:6712 failed: java.net.ConnectException: Connection refused: ip:6712
```

看了端口是storm配置工作worker端口范围, 看来是链接其他worker挂了, 登上对应机器看看那为啥, 用`ss -anp | grep 6712`和`ps -aux | grep pid`发现6712端口被另一个Topology占用了. 基于storm管理界面看Topology并没有使用到6712的worker. 妈的贼费解, 然后发现链接zk用的链接, 还不能直接kill掉.

发现问题就好解决了, 联系运维把临时端口范围调整一下就好了, 所有storm节点的临时端口范围调整为10000\~end, 避开storm的工作端口范围. 重启所有Topology问题解决了.

* 修改的配置文件`/etc/sysctl.conf` 中 `net.ipv4.ip_local_port_range`的配置.
* 执行 `sysctl -p /etc/sysctl.conf` 重新加载配置
* 执行`cat /proc/sys/net/ipv4/ip_local_port_range` 看是否生效

为啥老集群没这个问题呢? 发现老集群机器多, 差不多是2倍, 所以这个问题不严重.

## 辅助的知识

端口范围
* 0\~1023 固定端口 [IANA](https://www.iana.org/)上找, [Service Name and Transport Protocol Port Number Registry](https://www.iana.org/assignments/service-names-port-numbers/service-names-port-numbers.xhtml), 使用需要服务器root权限.
* 1024\~65535 临时端口, 虽然IANA建议从49152开始, 但并不是确定的.
    * 1024\~49151 注册端口实
    * 49152\~65535 未注册端口
