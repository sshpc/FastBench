# FastBench
Linux性能测试 FastBench 一键脚本 Linux跑分 小白跑分

## 介绍
* 不依赖其他程序,仅shell原生
* 快速测试 1分钟左右完成测试
* 测试结果仅供参考

## 一键执行

```sh
wget -N  http://raw.githubusercontent.com/sshpc/FastBench/main/FastBench.sh && chmod +x FastBench.sh && sudo ./FastBench.sh
```

## 示例

```sh

CPU 型号：QEMU Virtual CPU version 2.5+
CPU 主频：3695.998 MHz
CPU 核心数：2

1. CPU 测试...

 1.1 单核测试...
 单核测试完成：整数计算=3445，浮点计算=1240，累加计算=3938，合计=8623

 1.2 多核测试...
 多核测试完成：整数计算=6302，浮点计算=2296，累加计算=5526，合计=14124

2.内存测试...
内存读取速度：18086.22 MB/s 得分：72344

3.磁盘测试...
磁盘读取速度：106.02 Mb/s 得分：8481

==================== 测试结果 ====================
CPU 型号：QEMU Virtual CPU version 2.5+
CPU 主频：3695.998 MHz
CPU 核心数：2
单核得分：8623
多核得分：28248
CPU 分数：36871
内存分数：72344
硬盘分数：8481
总分：   117696
==================================================
```