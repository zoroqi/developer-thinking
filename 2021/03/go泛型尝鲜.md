# go泛型尝鲜

关注[鸟窝](https://colobu.com/), 在一个月前博客中提到1.17可能提供泛型功能. 最近go提供了泛型测试工具. [利好！极大可能在go 1.17中就能尝试泛型](https://colobu.com/2021/02/20/merge-dev-typeparams-to-master-during-Go-1-17/)和[Go 泛型尝鲜](https://colobu.com/2021/03/22/try-go-generic/)文章. 所以感觉测试感受一下啊.

## 安装和使用

```
go get golang.org/dl/gotip
gotip download
```

> 这里`download`狗血的下载路径是`~/sdk`, 发现好像没有看见可变参数. 蛋疼啊.

一个简单的实例, 将一个类型转换成另一个类型数据.

```go
package main

import (
    "fmt"
    "reflect"
    "strconv"
)

func mapper[T any, M any] (in []T, mf func (t T) M) []M {
    out := make([]M,len(in))
    for i,v := range in {
        out[i] = mf(v)
    }
    return out
}


func main() {
    l := mapper([]int{1,2,3,4,5}, strcov.Itoa)
    fmt.Println(reflect.TypeOf(l)) // []string
}
```

写代码, `gotip build -gcflags=-G=3 main.go` 可以编译和执行.

参考实例[go-generics-example](https://github.com/mattn/go-generics-example)

## 我对泛型的期望

我的期望很简单, 减少`interface{}`和不要让相同方法实现多次.

静态类型语言, 不支持泛型反而会引入很多不安全操作, 很多本身可以通过泛型解决的问题, 不得不引入`interface{}`来处理. 实例很简单就是"通用栈结构", 要么实现100个不同栈, 要么`[]interface{}`, 取出数据在强转, 自己给自己找麻烦. 实现一个线程安全的map, 两个`interface{}`然后各种强转.

很多常见操作需要实现很多个版本, 实例就是数学函数, `max`,`min`, 类似这种的, 不得不自己再去实现9个函数. 无意瞟见很多go项目都有一个专有的数学包, 就是解决大小比较等操作.

## 泛型语法和限制

这只是暂定语法, 等正式上线才能确定.

* 接口

```go
type Lesser[T any] interface{
   Less(y T) bool
}
```

* 结构体
```go
// 声明
type s[T any] struct {
    o T
}
// 方法会把泛型传下去, 方法上不用写泛型
// 使用
a := s[string]{o:"test"}

```

* 函数
```go
func name[T any] (a T, ...) T {
}
```

* any

代表任意类型, 等于`interface{}`

* 约束

类型约束, 当不使用`any`的情况需要指定约束条件

限制`Addable`的类型范围是数字, 才可以执行加法.
```go
type Addable interface {
  type int, int8, int16, int32, int64,
      uint, uint8, uint16, uint32, uint64, uintptr,
      float32, float64
}
```

当然限制也可以是泛型的接口和匿名接口.

```go
func toNum[T interface{num() int}](t T) int {
    return t.num()
}
```

因为是进行的接口限制, 所以类型传入都需要转换成指针(接口). 上一个例子调用的时候需要

```go
// fmt.Println(toNum(ab{})) 会报错, 无法编译, 显示 `wrong method signature`
fmt.Println(toNum(&ab{}))
```

而`any`是不收限制的.

* 类型推断

不用每次都指名类型, 可以自动推到出对应类型

## 个人感受

看语法和效果来说, 泛型更像一个接口集合和参数类型限制.

泛型是一把双刃剑, 想清楚了在用, 优先使用接口进行约束, 很多情况接口就够用了, 没有必要通过泛型进行约束.

泛型的引入会增加代码复杂度, 简单可以那java举例. 当单独拿出这一个方法的时候, 这里总共可以涉及三中动态类型, 在你不了解这段代码出处的话很难理解这是要干啥.
```java
<U> U poop(U poop1,
             BiFunction<U, ? super T, U> poop2,
             BinaryOperator<U> poop3);
```

这段代码是stream的reduce方法, 当知道出处后代码含义就确定\(这不是一个好例子).

泛型使用的个人建议
1. 是对系统的类型安全有提高就值得用. 当实现代码发现必须用`interface{}`才可以实现业务功能的时候, 应该考虑一下泛型.
2. 减少重复代码, 数学函数
3. 流式代码
4. 通用存储型结构

## 流式代码小试

```go
type stream[T any] struct {
    in chan T
}

func newStream[T any] (list []T) (*stream [T]) {
    out := make(chan T)
    go func() {
        for _,v := range list {
            out <- v
        }
        close(out)
    }()
    return &stream[T]{in:out}
}

// 这段编译不通过, 不知道为啥. 当把 M any删除, 然后强制指定m函数输出是string类型的时候是可以编译成功的.
func (s *stream[T]) mapper[M any] (m func (t T) M) (*stream[M]){
  out := make(chan M)
  go func() {
      for  n := range s.in {
          out <- m(n)
      }
      close(out)
  }()
  return &stream[M]{in:out}
}

func (s *stream[T]) foreach(m func (t T) ) {
    for n := range s.in {
        m(n)
    }
}
```

实现逻辑比较简单, 就是流式编程中`mapper`和`foreach`, 其他的`filter`和`reduce`没有在尝试. 可以参数`mattn`的代码.

## 更多参考

* [“能力越大，责任越大” – Go语言之父详解将于Go 1.18发布的Go泛型](https://tonybai.com/2021/02/18/typing-generic-go-by-griesemer-at-gophercon-2020/)
* [Go 泛型提案已提交，Go 1.18 beta 有望试用](https://www.oschina.net/news/126428/golang-generics-proposal)
