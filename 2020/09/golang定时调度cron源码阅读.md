# golang定时调度cron源码阅读

项目源码[cron](https://github.com/robfig/cron)

[官方文档](https://godoc.org/github.com/robfig/cron)

代码很少总共在2.5k. 功能简单整体代码就很精简. 有很多值得学习的技巧. 定时设置方案比crontab要多, 可以支持到秒级和特殊表达式.

## 简单使用

```golang
c := cron.New() // 创建一个调度
stop := make(chan struct{})
count := 0
// 一分钟一次
c.AddFunc("*/1 * * * *", func() {
    fmt.Println(time.Now())
    count++
    if count > 2 {
        stop <- struct{}{}
    }
})
c.Start() // 开始执行调度
<-stop
```

## 源码阅读

特别声明一下内容来源于tag:3.0.1

### 整体结构

核心逻辑采用ticker进行触发, 通过验证当前时间和期望时间之间的差值来判断是否需要运行, 修改期望运行时间, 然后go就好了. 采用goroutine执行定时任务, 很有可能产生goroutine泄漏, 到点运行之前状况不管. 这里spring的schedule就是线程池方案, 可能会出现排队或卡主的情况.

简单代码
```golang
for {
    case <-ticker.C: // 根据最小间隔计算
        for _,j := range jobs {
            if j.nextTime.After(now) { // 判断是否需要执行
                j.Next(now) // 计算下次执行时间
                go j.Run()  // 执行
            }
        }
    case <-stop:
        break
}
```

## 巧妙地设计

之前自己想实现过一个解析cron表达式的工具, 自己实现费劲的要死, 最后时限还是一个不完全的表达式. 我当初的结构大概是是. 解析是成功了, 但计算nextTime没成功, 就做放弃了.
```java
public class TimeField {
    private int[] runs; // 也可能是用的Set<Integer> 存储需要运行的时间
    private Type type;
}

public enum Type {
    MIN, HOUR, DAY, MONTH, WEEK
}
```

作者使用的方案是`uint64`存储需要运行的时间. 加一个type, 感觉比我的简单很多, 而且可以做进一步的运算. `uint64`刚好可以囊括, 秒, 分, 时, 日, 月, 周的所有时间范围, 最高位`1`表示`*`全部执行. 可以进行简单的与操作进行时间验证

以分钟为例
```
// 3分钟的时候发起执行
00000000 00000000 00000000 00000100
```

### 伟大的goto

计算下次运行时间, 中涉及到了goto, 第一个在项目中看见goto的使用.
```golang
WRAP:
    // 月份
    for 1<<t.Month() & s.Month == 0 {
        t = t.AddDate(0, 1, 0) // 添加一个月
        if t.Month() == time.January {
            goto WRAP
        }
    }
    // 日和周, 比较复杂但逻辑相似

    // 小时
    for 1<<t.Hour() & s.Hour == 0 {
        t = t.Add(1 * time.Hour) // 添加一个小时
        if t.Day() == 1 {
            goto WRAP
        }
    }
    // 分钟...
    // 秒...

```

每一个时间分割都有一个类似的判断, 将goto到开始处. 这里涉及到当前时间发生进位, 就需要从高位在进行一次计算.
```golang
if t.Day() == 1 {
    goto WRAP
}
```
`0 0 31 */2 *` 每二个月的31号需要运行, 实际执行的月份是 1,3,5,7月, 其它月份无法执行. 9月满足月份逻辑, 但日期不满足, 在执行会使下次日期进入10月1日, 这种情况需要从月份计算再一次时间, 直接进入下一年的1月31日.

> 当初自己实现计算next日期的时候, 就是因为从分钟向天计算导致逻辑复杂还总用时间计算不正确的情况

这里可以改成循环, 但还会使用到label, 最后和goto差不多, 所以goto还是可以的.

## 另一种方案cron方案

作者采用的是计算下次运行时间方案. 还有一种是用的验证方式. 这种方式不需要计算nextTime, 只需要验证当前时间点是否可以运行.

验证方式,
```golang
for {
    case <-ticker.C // 分钟
        for _,j := range jobs {
            if j.isRun() { // 现在时间是否需要执行
                go j.Run()
            }
        }
}
```

两种方法区别, 计算型要从天向分钟计算, 验证型是从分钟向天验证. 从实现角度来说, 验证型逻辑要简单很多. 当然验证型没法支持crontab意外的定时方式(活着先转换成crontab表达式), 比如spring框架下的 `fixedDelay` 上次执行完后间隔执行. 验证型的最小间隔很难做到秒级而计算型是可以做到的.

## golang小技巧

通过单个方法将一个函数包装成一个接口
```golang
type Job interface {
	Run()
}

type FuncJob func()

func (f FuncJob) Run() {f()}

func test(job Job) {
	job.Run()
}

func main() {
	test(FuncJob(func() {
		fmt.Println("hello world")
	}))
}
```

当然另一种方案是 struct中包裹一个方法声明字段

```golang
type StructJob struct {
		F func()
}

func (s StructJob) Run() {
		s.F()
}
```

