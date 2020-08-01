# 不可小觑的goto

看到一个讲`goto`的不好的文章[GOTO 语句被认为有害](https://www.emon100.me/goto-translation/), 最后留有一段使用`goto`的代码. 代码主要作用是LR解析器. 想把这个代码转换为非goto的代码.

## 转换
这是我以golang进行的转换, 感觉不是很复杂. 代码不完全, 感觉可能不对. 始终没有找到那个1988年的LR解析器代码, 这里一定设计到了全局的堆栈等状态, 不清楚`shift`和`reduce`到底执行了什么, 最难理解的是`reducing`这个标签是干什么的, 没看见用的地方, 感觉这里会产生特殊的问题.

*特殊声明我个人猜测原始代码是`c`的.*

原始代码
```c
int parse()
{
    Token   tok;

reading:
    tok = gettoken();       // 循环开始获取一个状态
    if (tok == END)         // 执行结束(ACCEPT)
        return ACCEPT;
shifting:
    if (shift(tok))         // 这里和reading产生外层循环, 循环退出条件 tok == END
        goto reading;
reducing:                   // 作用不明的标签
    if (reduce(tok))        // 这里和shifting产生了内层循环, 循环退出条件是, shift(token) == true(1)
        goto shifting;
    return ERROR;           // shift和reduce都返回false(0), 执行结束(ERROR)
}
```


我转换为for循环的golang代码
```golang
func forParse() Status {
    var tok Token
    for {
        tok = gettoken()        // lable reading
        if tok == END {         // END
            return ACCEPT
        }
        for !shift(tok) {       // label shifting. true goto reading, false: reducing
            if !reduce(tok) {   // label reducing. true goto shifting, false: END
                return ERROR    // END
            }
        }
    }
}
```

在HN上找到一个更简单的[HN](https://news.ycombinator.com/item?id=20794481)

```c
int parse(void)
{
  Token tok;
  while ((tok = gettoken()) != END)
  {
    while (!shift(tok))
      if (!reduce(tok))
        return ERROR;
  }
  return ACCEPT;
}
```

## 有意思的goto
这个很神奇的关键字, `无条件跳转`. `goto`我理解是可以等价于`for`, `break`, `throw`这三种操作, 即产生循环, 跳出循环, 抛出异常. 一个语言可以支持者三种操作就可以尽量不用`goto`语句.

之后在某个技术群里看见`golang`竟然有`goto`语句. 一直以为`golang`是没有`goto`语法的, 有的是`java`相似的循环跳转`break label/continue label`这种. 然后在`golang`源码中找到了`goto`的使用(在一个数学函数计算中).

只要`goto`想清楚的了就可以用, 不要畏惧, 核心要表达清晰就可以了. 很多时候无条件跳转反而简单,异常处理, 快速结束循环, 可能比`flag`这种方式更加清晰简单.

而我认为有限范围内(不跳出方法)的`goto`相对还好理解, 而递归可能更加复杂, 尤其是多个函数的循环递归, 开发生涯中竟让见过多方法形成的递归(对html dom操作的功能, 印象中是4个方法互相调用). 更复杂的就是`goto加递归`的代码, 那将会真的进入逻辑上的深渊.

## LR解析

[wiki](https://zh.wikipedia.org/wiki/LR%E5%89%96%E6%9E%90%E5%99%A8)

#### LR分析器的结构

以表格为主（table\-based）自底向上的分析器可用图一描述其结构，它包含：

* 一个输入缓冲器，输入的源代码存储于此，分析将由第一个符号开始依序向后扫描。
* 一座堆栈，存储过去的状态与化简中的符号。
* 一张*状态转移表*（goto table），决定状态的移转规则。
* 一张*动作表*（action table），决定目前的状态碰到输入符号时应采取的文法规则，输入符号指的是终端符号（Terminals）与非终端符号（Non\-terminals）。

#### 分析算法
1. 将结尾字符$与起始状态0依序压入空堆栈，之后的状态与符号会被压入堆栈的顶端。
2. 根据目前的状态以及输入的终端符号，到动作表中找到对应动作：
    * 移位（shift）s `n`:
        * 将目前的终端符号由输入缓冲器中移出并压入堆栈
        * 再将状态`n`压入堆栈并成为最新的状态
    * 化简（reduce）r `m`:
        * 考虑第`m`条文法规则，假设该文法的*右边（right\-hand side）*有X个符号，则将2X个元素从堆栈中弹出
        * 此时过去的某个状态会回到堆栈顶端
        * 在*状态转移表*中查找此状态遇到文法*左边（left\-hand side）*的符号时的状态转移
        * 将文法左手边的符号压入堆栈
        * 将查找到的新状态压入堆栈
    * 接受，输入字符串解析完成。
    * 无对应动作，此情形即为文法错误。
3. 重复步骤二直到输入的字符串被接受或侦测到文法错误。
