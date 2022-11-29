---
tags: ["java", "内存泄漏", "framework/spring", "漏洞", "gateway"]
---

# 记一次 OutOfDirectMemoryError 内存泄漏后续

前一篇内容 [记一次OutOfDirectMemoryError内存泄漏](记一次OutOfDirectMemoryError内存泄漏.md).

之前简单的记录了我的复现过程和定位过程, 反馈给同事后, 他测试竟然不成功. 继续进行问题定位, 找到了稳定触发方式, 需要有执行 POST 的请求, 并且需要有 RequestBody 内容.

核心问题代码
```java
1. DataBufferUtils.join(exchange.getRequest().getBody())
2.     .flatMap(dataBuffer -> {
3.         DataBufferUtils.retain(dataBuffer);
4.         // DataBufferUtils.release(dataBuffer);
5.         return chain.filter(exchange.mutate().request(mutatedRequest).build());
6.     });
```

第一行中的 "`exchange.getRequest().getBody()`" 对 RequestBody 进行处理

第三行 retain 对 RequestBody 的引用计数加一

第五行 执行后续的 Filter 链

因为没有第四行对 RequestBody 的引用计数减一, 长时间运行导致内存泄漏.

## 问题修正

在这个项目上我是没有能力进行修复的, 因为看了项目代码, 我至今无法理解这个 GlobalFilter 要干什么. 询问同事也没给出一个明确的答案, "说是为了解决另一个 Filter 的某些问题, 从网上找到这段代码就解决了". 那个问题可能是"一个 RequestBody 不能重复读". 满足需求的情况下可能需要这么修改代码, 但不知道具体的目的这么修改大概率是错误的.

```java
DataBufferUtils.join(exchange.getRequest().getBody())
    .flatMap(dataBuffer -> {
        DataBufferUtils.retain(dataBuffer);
        try {
            return chain.filter(exchange.mutate().request(mutatedRequest).build());
        } finally {
            DataBufferUtils.release(dataBuffer);
        }
    });
```

## 不懂的框架

没用做过 Spring Gateway 的二次开发, 也没有用过 Webflux 框架. Webflux 的代码控制流程还是有区别的, 看来需要正式学习 Reactor 的编程方式了.

## 一个狗血的请求

我顺便做了个测试, GET 请求提交 Body, Webflux 竟然可以接数据. 在几年前的工作中遇到过这样的写法, GET 请求并且需要提交 Body. 当时是接手别人的代码, 根本没看具体的 Http 请求处理, 只看第三方接口描述, 文档, 返回结构; 时间富裕了发现请求的时候是用的匪夷所思的 GET + Body 的请求方式.

自己尝试写个请求 demo, 发现我常用的两个 Java 库\(HttpClient和OKHttp\) 都不支持这种方式请求. 接手的不是 Java 项目, 用的 golang 默认库竟然可以成功. 最后让我更加惊讶的是 SpringBoot 竟然支持这种写法的 Controller. 而接口提供方最暴力的是, 必须是 GET 请求, 提交内容必须在 Body 部分.
