# G1GC的特殊情况

最近一个需求完成后本机测试正常, 而到正式机上测试就死活起不来. 日志一直报错`Java OOM`错误. 在极端的情况下发现一个不适合使用G1GC作为垃圾回收器的情况.

## 背景

服务功能是BloomFilter的简单的接口包装, 主要功能就`添加`和`包含`两个, 单个`bitmap`用`[]byte`实现, 占用空间45M\~46M左右. 基于预计量计算需要3000个bitmap, 占用内存130G左右. 最初设想内存分配方式是10G\~15G新生代, 145G\~150G老生带, 20G剩余物理内存, 最接近的物理机标准188G的.

## 问题的开始

启动参数指定了最大内存160G使用使用G1GC. 服务启动很快发生`OOM`, 通过`watch free`查看`JVM`内存申请始终维持在120G就不再申请物理内存了, 开始`OOM`, 明明还有很多内存可以使用, 为啥就不申请了呢?

## 问题的解决

第一反应, 看gc日志,`jstat -gc`查看运行内存状态, 发现没啥问题, 内存空间是有的, 就是无法申请到. 这是为啥完全不理解.

简单调整内存中bitmap数量减少到2000个, 服务就正常启动了. 并且内存量可以突破120G申请到140G的物理内存, 明明我调小了实际内存, 反而不`OOM`了还可以申请到更多的内存. 这就更蛋疼了.

尝试添加`Xmn/XX:NewRatio`指定新生代大小, 不使用G1GC的动态分配. 发现没啥用, 依旧是`OOM`.

反正服务功能简单, 就一个大的bitmap切分成了3000个小的, 也用不到G1GC的特性, 就换到常用方案`CMS+ParNew`了, 发现立刻好了. 简单指定了新生代大小后线上压测, 没啥问题就好了.

## 为什么

工作告一段落, 为啥G1GC不好使呢. 明明内存是够的, 为啥就`OOM`了, 这到底发生了什么.

在看了G1GC的基本简介后, 发现了可能的原因. G1GC采用region方式将内存分成大量小块, 每个小块分为4种状态, 未使用, 新生代, 老生代, 大内存块(Humongous). 每个region大小在2M\~32M的大小, 启动决定不可变, 当申请内存超过region的一半就会判断是`大对象`申请内存. 大对象可能分配给一个region后剩余部分会不再进行分配, 这会产生内存碎片, 导致总内存是够的但是无法正全部内存的情况.

基于以上猜想计算内存使用
```
160GB = 5120 region, 每个块32M
1bitmap = 45M
3000bitmap = 3000*45MB = 131.8GB ~= 4219 region, 最小region数量
2000bitmap = 2000*45MB = 87.89GB ~= 2813 regino, 最小region数量

假设大内存块, 可能会产生内存存片
1bitmap需要两个2region存储
3000bitmap = 6000region > 160G => OOM
2000bitmap = 4000region < 160G => SUCCESS
```

通过计算可能猜想是正确的, 剩下就是验证了.

验证代码
```java
public class Block {
    byte[] block;
    public Block(int size) {
        block = new byte[size];
        block[100 % size] = 10;
    }
}

public static void main(String[] args) throws InterruptedException {
    int blockSize = 100;
    List<Block> block = newBLock(blockSize);
    System.out.println(block.size())
}

public static final int BLOCK_SIZE = MB * 1 + KB * 1;
public static List<Block> newBLock(int size) throws InterruptedException {
    List<Block> blocks = new ArrayList<>();
    for (int i = 0; i < size; i++) {
        blocks.add(new Block(BLOCK_SIZE));
    }
    return blocks;
}
```

启动参数
```
java -XX:+UseG1GC -XX:G1HeapRegionSize=2m  -Xmx200m -XX:+PrintGC -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps -XX:+PrintGCApplicationStoppedTime -Xloggc:./gc.log  -cp region_test.jar Main
```

实际需要内存在100.09MB, 使用50%堆内存. 但发生了`OOM`

每个`block`大小1.0009MB, 刚好大于region的一半多一点点. 100个`Block`就需要100个region, 而我内存总共100个region, 最后一个Block的创建会产生`OOM`, 通过`jstat -gc`也可以观察到.
```
 S0C    S1C    S0U    S1U      EC       EU        OC         OU       MC     MU    CCSC   CCSU   YGC     YGCT    FGC    FGCT     GCT
 0.0   2048.0  0.0   2048.0 28672.0   2048.0   174080.0   95730.6   4864.0 2746.7 512.0  295.8       1    0.002   0      0.000    0.002
```
OU只是使用OC的一半, 而Block已经无法申请了.

只要把BLOCK_SIZE调整到`BLOCK_SIZE = MB * 1 - KB * 1`立刻就好了. 最后我的猜想得到了验证.

为啥我会用G1GC内, 因为需要内存多久选择G1, 使用JVM大神寒泉子提供的JVM工具, [perfma](http://xxfox.perfma.com/), 简单方便可以生成JVM模板. 我一般都是这样生成的, 只是这次太特殊工具失效了.

在查G1参数的时候找到官方的一个介绍同[Garbage First Garbage Collector Tuning](https://www.oracle.com/technical-resources/articles/java/g1gc.html) [Garbage First Garbage Collector Tuning中文](https://www.oracle.com/cn/technical-resources/articles/java/g1gc.html)

> Humongous Objects and Humongous Allocations 部分做了详细介绍

## 反思

基于以上的分析, 其实我可以依旧使用G1GC, 但要调整bitmap大小控制在接近32M但不超过32M, 就可以正常启动了.

当然核心修改还是不采用这中180G部署方案, 采用hash多来几台机器或使用redis进行存储可能更好.

这个实现很特殊, 很少有对象会占用巨大的内存块, 而且这些对象是半永久的对象(服务启动后就不会调整了). 特殊情况特殊对待, 针对大堆还是优先考虑G1GC比较好.

使用golang实现了一版本, 从压测看golang性能好很多, 测试将bitmap控制在5GB以内. 功能简单内存分布也简单, golang就产生了优势.
