# java线程池

一个同事突然问我线程池中的线程如何退出. 我记忆中是从queue中poll不出数据超时就结束了. 线程池核心的逻辑就是, 循环获取任务并执行, 未执行的任务排队等待.

```
for (task ;task!=nulltask == queue.poll() ) {
    task.run()
}
```

同事的问题是, 1. 线程如何退出? 2. 异常后线程会怎么样?

### 线程如何退出

源码很简单, 当前线程数小于coreSize就使用take, 不然就poll(timeout). 这里.

这里涉及到两个问题
1. 线程是否有核心和非核心的状态?
2. 如何保证核心线程数?

问题1的答案是没有.

在最开始想当然是有区分的. 这个偏差来源与一种先入为主的直觉, 既然有参数就应该有所区分, 再加上addWorker方法还有一个标志位, 导致看源码理解很久咋保存的状态.

问题2的解答, 既然没有特殊状态保证就需要一定手段来保存核心线程数. 方式就是多循环几次. 以此次来实现核心线程数的保证.

```java
for (;;) {
    // 判断核心线程数量
    boolean timed = allowCoreThreadTimeOut || wc > corePoolSize;
    try {
        Runnable r = timed ?
            workQueue.poll(keepAliveTime, TimeUnit.NANOSECONDS) :
            workQueue.take();
        if (r != null)
            return r;
        timedOut = true;
    } catch (InterruptedException retry) {
        timedOut = false;
    }
}
```

### 异常后线程会怎么样

异常后把异常抛出去就好了, 然后死循环结束, 最后尝试创建一个新的线程就好了.

### 多线程的经验

看源码设计到多线程一般都是一个死循环, 直到满足某种条件或异常才退出, 所有判读都是一个大循环来保证一遍一遍执行全流程. 任何一个状态都会发生变化, 都需要执行一个完整的判断. **不要搞太多快速路劲.**

这是java线程中获得任务的代码逻辑.
```java
private Runnable getTask() {
    boolean timedOut = false;
    for (;;) {
        // 获得状态
        int c = ctl.get();
        int rs = runStateOf(c);
        // 验证线程池是否停止
        ....
        // 线程数量
        int wc = workerCountOf(c);
        // 验证线程数量是否超过配置
        ....
        // 获取任务
         try {
                Runnable r = timed ?
                    workQueue.poll(keepAliveTime, TimeUnit.NANOSECONDS) :
                    workQueue.take();
                if (r != null)
                    return r; // 没有获取会继续执行
                timedOut = true;
            } catch (InterruptedException retry) {
                timedOut = false;
            }
    }
}
```

golang sync.Mutex Lock流程. 存在一个快速路径, 剩下的就是循环改变状态. 直到成功为止
```golang
func (m *Mutex) Lock() {
    // 快速路劲
    // Fast path: grab unlocked mutex.
    if atomic.CompareAndSwapInt32(&m.state, 0, mutexLocked) {
        return
    }
    // Slow path (outlined so that the fast path can be inlined)
    m.lockSlow()
}

func (m *Mutex) lockSlow() {
    var waitStartTime int64
    starving := false
    awoke := false
    iter := 0
    old := m.state
    // 一个死循环
    for {
        // 一个超长的状态判断
    }
}
```
