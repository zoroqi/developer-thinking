# 记一次 OutOfDirectMemoryError 内存泄漏

开心的过年游戏时间被一个线上报警中断了, 搞得我很郁闷, 随后开始了痛苦的修复过程.  看了服务监控和日志我服务没有明显问题, 就是流量少了点. 根据反馈的日志看问题应该是出现在中间的网管层. 联系网关同事修复, 修复后问原因, 是线上网关有一个内存泄漏的问题. 报错内容
```
2022-02-0... [t] ERROR Loggers.java:319 - [id: 0x00130e48, L:/127.0.0.1:8080 - R:/127.0.0.1:29842] onUncaughtException(SimpleConnection{channel=[id: 0x00130e48, L:/127.0.0.1:8080 - R:/127.0.0.1:29842]})
io.netty.util.internal.OutOfDirectMemoryError: failed to allocate 16777216 byte(s) of direct memory (used: 2063597575, max: 2075918336)
at io.netty.util.internal.PlatformDependent.incrementMemoryCounter(PlatformDependent.java:754)
at io.netty.util.internal.PlatformDependent.allocateDirectNoCleaner(PlatformDependent.java:709)
at io.netty.buffer.PoolArena$DirectArena.allocateDirect(PoolArena.java:755)
at io.netty.buffer.PoolArena$DirectArena.newChunk(PoolArena.java:731)
```

看错误内容是 netty 的 OutOfDirectMemoryError, 可以简单得出结论, 不定什么地方出现问题导致的内存泄漏, 而内存泄漏的问题通常可以重启服务解决. 保存日志, 重启服务问题解决了. 

还好我可以拿到网关的代码和日志, 假日结束后开始探索为啥会泄漏.

## 复现问题

创建以 springboot + gateway 的项目, 测试用的主要版本

```xml
<parent>  
 <groupId>org.springframework.boot</groupId>  
 <artifactId>spring-boot-starter-parent</artifactId>  
 <version>2.3.2.RELEASE</version>  
 <relativePath/>  
</parent>

<dependency>  
 <groupId>org.springframework.cloud</groupId>  
 <artifactId>spring-cloud-starter-gateway</artifactId>  
 <version>2.2.5.RELEASE</version>  
</dependency>
```

根据报错信息 "PlatformDependent.incrementMemoryCounter" 看报错代码. 
```java
if (DIRECT_MEMORY_COUNTER != null) {  
  long newUsedMemory = DIRECT_MEMORY_COUNTER.addAndGet((long)capacity);  
   if (newUsedMemory > DIRECT_MEMORY_LIMIT) {  
     DIRECT_MEMORY_COUNTER.addAndGet((long)(-capacity));  
     throw new OutOfDirectMemoryError("failed to allocate " + capacity + " byte(s) of direct memory (used: " + (newUsedMemory - (long)capacity) + ", max: " + DIRECT_MEMORY_LIMIT + ')');  
}
```

核心校验的是一个统计用的 AtomicLong 变量(DIRECT_MEMORY_COUNTER). 这样就比较好监控了, 启动的时候创建一个线程循环打印 DIRECT_MEMORY_COUNTER 变量(私有变量需要反射拿到).  启动项目需要添加 `-XX:MaxDirectMemorySize=1M -Dio.netty.maxDirectMemory=1M` 方便复现问题和增加内存空间压力.

测试发现只有在请求后 DIRECT_MEMORY_COUNTER 才会增加, 并以 1024 递增直到溢出. 这就确定了泄漏的原因和请求有关. 现在问题有两种可能
1. 写的业务用 Filter 有问题
2. spring-gateway 有问题

本着"我是傻逼, 有问题一定是我写代码引发"的原则, 优先排查 Filter. 写一个新的 Filter, Filter 直接拦截请求, 让到网关的请求直接返回不向后转发了; 测试后发现问题依旧存在, 那问题可能出现在 gateway 本身上了. 

既然可能在 gateway 上, 那就砍掉所有业务代码, 纯 gateway 尝试看看, 发现没有问题好了, 说明问题还在业务代码上. 发现开发同事写了两个 GlobalFilter, 直接停掉两个 Filter 问题也好了. 二分法测试结果一个 GlobalFilter 有问题, Filter 死活我没看懂要干啥.

出问题的代码
```java
public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
    return DataBufferUtils.join(exchange.getRequest().getBody())
            .flatMap(dataBuffer -> {
                DataBufferUtils.retain(dataBuffer);
                Flux<DataBuffer> cachedFlux = Flux
                        .defer(() -> Flux.just(dataBuffer.slice(0, dataBuffer.readableByteCount())));
                ServerHttpRequest mutatedRequest = new ServerHttpRequestDecorator(
                        exchange.getRequest()) {
                    @Override
                    public Flux<DataBuffer> getBody() {
                        return cachedFlux;
                    }
                };
                return chain.filter(exchange.mutate().request(mutatedRequest).build());
            });
}
```

没写过 gateway 的 Filter 代码, 也不理解代码是要干什么, 就按照行查看函数是什么意思.

其中 "DataBufferUtils.retain" 函数是用来递增引用计数用的, 这一定存在一个相反的操作, 这就直接找到了 release 函数. 代码中没有执行 release 操作导致计数错误, 没有被释放. 

## 修复问题

添加了 "DataBufferUtils.relase(dataBuffer);" 调用就好了.
