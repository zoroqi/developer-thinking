# go的依赖复杂性

自己写了个生成go mod的依赖树的小工具[dependency-graph](https://github.com/zoroqi/dependency-graph), 核心功能就是解析`go mod graph`然后构建依赖树, 打印输出. 更详细的go依赖可以参考[gomod依赖](../06/gomod依赖.md). 小工具采用的是重复输出, 测试用的项目依赖就很多, 大概打印了1700多行. 闲来无事想换一个项目打印看看, 选择了[prometheus](https://github.com/prometheus/prometheus)直接打印了71Mb的文件, 依赖太多了, 所以对小工具做了升级可以排除部分包的打印.

这里发现go mod的依赖管理和maven相差很多. maven产生的依赖树和go mod比起来小很多, maven的依赖一个hbase这种组件就会间接依赖一大把组件. 而go mod稍微依赖几个组件, 就会引入一大把依赖. 主要原因版本中涉及到对没有tag项目的兼容, 直接使用`v0.0.0-commit`, 这就会产生各种特殊的依赖关系. 而版本通常最混乱的还是golang自己的包`golang.org/x`这里边的包是恐怖直接, 很多都没有`tag`, 依赖的很随意. 再加上go mod的版本选择, 只要依赖了稍微大一点的组件就可以导致依赖混乱. 个人比较喜欢maven的依赖版本冲突解决方案, 按照深度算, 而不是版本算.

golang的项目对老板的兼容要做到更好, 不然更容易出现bug.

简单举例, 从`golang.org/x/tools@v0.0.0-20200403190813-44a64ad78b9b` 打印出来的依赖, 间接依赖了三个版本的`x/net`, 还存在自身依赖自身不同版本的情况
```
|-golang.org/x/tools@v0.0.0-20200403190813-44a64ad78b9b
|    |-github.com/yuin/goldmark@v1.1.27
|    |-golang.org/x/mod@v0.2.0
|    |    |-golang.org/x/crypto@v0.0.0-20191011191535-87dc89f01550
|    |    |    |-golang.org/x/net@v0.0.0-20190404232315-eb5bcb51f2a3 // net 1次
|    |    |    |    |-golang.org/x/crypto@v0.0.0-20190308221718-c2843e01d9a2
|    |    |    |    |    |-golang.org/x/sys@v0.0.0-20190215142949-d0b11bdaac8a
|    |    |    |    |-golang.org/x/text@v0.3.0
|    |    |    |-golang.org/x/sys@v0.0.0-20190412213103-97732733099d
|    |    |-golang.org/x/tools@v0.0.0-20191119224855-298f0cb1881e
|    |    |    |-golang.org/x/net@v0.0.0-20190620200207-3b0461eec859 // net 2次
|    |    |    |    |-golang.org/x/crypto@v0.0.0-20190308221718-c2843e01d9a2
|    |    |    |    |    |-golang.org/x/sys@v0.0.0-20190215142949-d0b11bdaac8a
|    |    |    |    |-golang.org/x/sys@v0.0.0-20190215142949-d0b11bdaac8a
|    |    |    |    |-golang.org/x/text@v0.3.0
|    |    |    |-golang.org/x/sync@v0.0.0-20190423024810-112230192c58
|    |    |    |-golang.org/x/xerrors@v0.0.0-20190717185122-a985d3407aa7
|    |    |-golang.org/x/xerrors@v0.0.0-20191011141410-1b5146add898
|    |-golang.org/x/net@v0.0.0-20200226121028-0de0cce0169b // net 3次
|    |    |-golang.org/x/crypto@v0.0.0-20190308221718-c2843e01d9a2
|    |    |    |-golang.org/x/sys@v0.0.0-20190215142949-d0b11bdaac8a
|    |    |-golang.org/x/sys@v0.0.0-20190215142949-d0b11bdaac8a
|    |    |-golang.org/x/text@v0.3.0
|    |-golang.org/x/sync@v0.0.0-20190911185100-cd5d95a43a6e
|    |-golang.org/x/xerrors@v0.0.0-20191204190536-9bdfabe68543
```
