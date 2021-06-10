# 对spring注解理解的片面

## 无法理解Qualifier

开发中同事用了`@Autowired`和`@Qualifier`组合, 我想当然的认为这两个存在冲突. 因为Autowired是根据上下文匹配, Qualifier是需要指定具体名称的. 所以组合使用有一种"脱了裤子放屁"的感觉. 要是需要指定名字那我直接`@Qualifier`就好了, 为啥还要配合`@Autowired`. \(我信誓旦旦的说, 同事竟然没有坚持自己的想法.\). 我没有用过`Qualifier`, 我需要指定名字都是用的`@Resource`这个注解. 我想当然的理由也是来源于`@Resource`.

只使用`@Qualifier`的话是无法实现注入的, 属性还是`null`.

`Qualifier`的描述是起到限定作用, 但不进行注入.

> This annotation may be used on a field or parameter as a qualifier for candidate beans when autowiring. It may also be used to annotate other custom annotations that can then in turn be used as qualifiers.

我好奇的是为啥`Qualifier`不直接注入而是一个修饰, 看声明文件, Qualifier可以写在类上, 说明这个注解也可以用作起名. 反正我不理解为啥要会存在一个修饰名词, Service本身也可以起名, Component也可以为啥还要加这个修饰词. 反正有中浓浓"脱裤子放屁"的味道.

继续google找到了高级用法. 可以实现收集操作, 将多个收集到一起.

```java
@Qualifier("testservice")
@Autowired
public List<TestService> person;
```

## Lazy的理解

这是很早很早之前的一个测试, Lazy如何定义是否使用到. 我问同事, 同事的答案很干脆第一使用的时候, 我想当然的也就接受了这个答案. 后边一个需求可以到使用的时候在初始化, 最后测试才知道第一次`使用`是什么, 扫描到的非懒加载的类所依赖的都会进行初始化, 一个需要执行初始初始化的Bean依赖的所有Bean都会进行初始化, 这个和Lazy无关. 只有完全不在初始化中的Bean标记Lazy才可以实现懒加载.

但我个人建议没有特殊情况不要用懒加载.

, #spring #注解 #无知 #懒加载
