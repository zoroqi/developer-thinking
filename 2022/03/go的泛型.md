---
aliases:
- go的泛型
date: "2022-03-17"
tag:
- go
- 泛型
---

# go的泛型

这是去年还在测试的时候的一篇内容 [[go泛型尝鲜]], 距今已经一整年了.

主要文档
* [简单泛型实例](https://go.dev/doc/tutorial/generics)
* [为什么要用泛型](https://go.dev/blog/why-generics) 文中的实例都已经没有意义了, 文法变动太多
* [release note|generics](https://go.dev/doc/go1.18#generics)

泛型文法说明散乱在 [spec](https://go.dev/ref/spec) 中, 看起来很费劲, 最好结合 release note 中的指引来看. 

声明部分的文法结构 [TypeParameters](https://go.dev/ref/spec#TypeParameters)

## 正式第一感受

### 人脑解析更累了

依旧很讨厌"[]"这人方案, 看的太难受了. 人脑解析成本越来越高了, 当然比 c/c++ 好一些. 之前的复杂嵌套还是 slice,map,func 的嵌套, 现在有多了一个泛型. 

就像这也是一个合法的结构, 看起来已经很难受了
```go
map[string]func(float64) []map[string][]int
```

现在可以继续升级到这种方式了
```go
func build[S any, T ~int, V string](s S) map[string]func(S) []map[V][]T {
//...
}

// 调用的时候效果
r := m["1"]("2")[0]["3"][0]
```

当然不要在代码中构建这种结构, 最好多起一些名字, 不要这种复杂嵌套. 没有什么设计需要这么复杂的声明. 看调用效果可以赶上 `****i` 的代码了.

### 误解了的文法

一个狗血的文法, 最开始创建一个有泛型的函数类型的时候, 显示错误.
```go
type test func[S any](S)
```

我最开始以为和函数声明相似, 是放在 func 和 参数之间, 后来测试发现是放在名称后面

```go
type test[S any] func(S)
```

### 期望好像没有达成

[[go泛型尝鲜]] 中那个 stream 的例子, 我依旧没有测试成功, 感觉好像无法支持, 从语法规范中关于 [Method](https://go.dev/ref/spec#Method_declarations) 的说明感觉无法支持

```
MethodDecl = "func" Receiver MethodName Signature [ FunctionBody ] .
Receiver   = Parameters .
```

要是不成功, 这个就比较蛋疼了, 函数流式编程中需要的就是 method 上有两个限制, 一个泛型类型来源于 struct 部分, 一个来源于 method 自身携带.

尝试这么写是可以的, 但就没有办法流了

```go
func mapper[T any, M any](s *stream[T], m func(t T) M) *stream[M] {  
    out := make(chan M)  
    go func() {  
        for n := range s.in {  
            out <- m(n)  
        }
        close(out)  
    }()
    return &stream[M]{in: out}  
}
```

嵌套式的写法将很难看懂, 一个简单的转换和循环打印, 变成了这么个效果, 太难受了. 感受到一种 lisp 的感觉. java 的 stream 是顺序从前向后读, 这个是从内向外读.
```go
ss := []string{"1", "2", "3"}
foreach(
    mapper(
        mapper(
            newStream(ss),
            func(s string) int {
                i, _ := strconv.Atoi(s)
                return i
            }),
        func(i int) int {
            return i * 100
        }),
    func(i int) {
        fmt.Printf("num:%d\n", i)
    })
```

## 泛型基本结构

重要说明
* `~` 某一类型和该类型的所有别名类型
* `any` 任意类型可理解为 interface{}
* `|` 类型之间是或关系

泛型的限制, 竟然使用 interface 做限制, 看来接口的含义发生了变化 [General interfaces](https://go.dev/ref/spec#General_interfaces)

```go
// 只能是 int 类型
interface {
	int
}

// 表示具有基础类型 int 的所有类型
interface {
	~int
}

// 表示具有基础类型 int 的所有类型, **并且** 需要实现 String() 方法
interface {
	~int
	String() string
}

// 可以定义, 但无法满足"一个类型同时是 int 有是 string"
interface {
	int
	string
}
// 表示具有基础类型 float32 或 float64 的所有类型
type Float interface {
	~float32 | ~float64
}
```

### interface

感觉泛型最后可以理解为对接口含义的扩充, 之前接口中只有函数声明, 现在追加了类型相关的内容.

反正这种感觉怪怪的, 我理解泛型是对类型的限制, 现在发现不光是类型, 还可以是某些具体的方法. 我对接口的理解倾向于一种特殊的类型.
