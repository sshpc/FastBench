#!/bin/bash
# FastBench跑分 Linux性能测试一键脚本
# Author:SSHPC <https://github.com/sshpc>
#字体颜色定义
_red() {
  printf '\033[0;31;31m%b\033[0m' "$1"
  echo
}
_green() {
  printf '\033[0;31;32m%b\033[0m' "$1"
  echo
}
_yellow() {
  printf '\033[0;31;33m%b\033[0m' "$1"
  echo
}
_blue() {
  printf '\033[0;31;36m%b\033[0m' "$1"
  echo
}

environmentaltest() {
  #检查关键程序是否存在
  commands=("bc" "awk" "pkill" "dd" "lsblk")
  pass=1
  for command in "${commands[@]}"; do
    if ! command -v "$command" >/dev/null 2>&1; then
      _red "$command 命令不存在,请自行安装"
      pass=0
    fi
  done
  if [[ "$pass" == 0 ]]; then
    exit 0
  fi

  # 退出脚本时清理所有子进程
  cleanup() {
    pkill -P $$
    exit 1
  }
  trap cleanup INT TERM EXIT

}

#CPU测试

cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | awk -F': ' '{print $2}')
cpu_cores=$(grep -c "^processor" /proc/cpuinfo)
cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | awk -F': ' '{print $2}')

# 初始化分数
single_core_score=0
multi_core_score=0

# 测试时间（秒）
test_duration=5

# 定义整数运算
integer_test() {
  local iterations=0
  local start_time=$(date +%s)
  while (($(date +%s) - start_time < test_duration)); do
    # 简单的整数运算
    result=$((123456 * 789 + 98765 / 123 - 45678))
    ((iterations++))
  done
  echo $iterations
}

# 定义浮点运算
float_test() {
  local iterations=0
  local start_time=$(date +%s)
  while (($(date +%s) - start_time < test_duration)); do
    # 简单的浮点运算
    result=$(echo "scale=5; 123.456 * 7.89 + 9.876 / 1.23 - 4.567" | bc)
    ((iterations++))
  done
  echo $iterations
}

# 定义累加运算
accumulation_test() {
  local iterations=0
  local sum=0
  local start_time=$(date +%s)
  while (($(date +%s) - start_time < test_duration)); do
    # 累加操作
    sum=$((sum + iterations))
    ((iterations++))
  done
  echo $iterations
}

# 单核测试
single_core_test() {
  _blue "-> 正在进行单核测试..."
  int_single=$(integer_test)
  float_single=$(float_test)
  accum_single=$(accumulation_test)
  single_core_score=$((int_single + float_single + accum_single))
  echo "单核测试完成：整数运算=$int_single, 浮点运算=$float_single, 累加运算=$accum_single, 单核得分=$single_core_score"

}

# 多核测试
multi_core_test() {
  _blue "-> 正在进行多核测试..."
  local total_int=0
  local total_float=0
  local total_accum=0

  # 保存子进程PID和结果文件
  pids=()
  results_dir=$(mktemp -d)

  # 多核整数测试
  for ((i = 0; i < cpu_cores; i++)); do
    (integer_test >"$results_dir/int_$i") &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait $pid
  done
  for ((i = 0; i < cpu_cores; i++)); do
    total_int=$((total_int + $(cat "$results_dir/int_$i")))
  done

  # 多核浮点测试
  pids=()
  for ((i = 0; i < cpu_cores; i++)); do
    (float_test >"$results_dir/float_$i") &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait $pid
  done
  for ((i = 0; i < cpu_cores; i++)); do
    total_float=$((total_float + $(cat "$results_dir/float_$i")))
  done

  # 多核累加测试
  pids=()
  for ((i = 0; i < cpu_cores; i++)); do
    (accumulation_test >"$results_dir/accum_$i") &
    pids+=($!)
  done
  for pid in "${pids[@]}"; do
    wait $pid
  done
  for ((i = 0; i < cpu_cores; i++)); do
    total_accum=$((total_accum + $(cat "$results_dir/accum_$i")))
  done

  # 删除临时结果文件
  rm -rf "$results_dir"

  multi_core_score=$((total_int + total_float + total_accum))
  echo "多核测试完成：整数运算=$total_int, 浮点运算=$total_float, 累加运算=$total_accum, 多核得分=$multi_core_score"

}

#内存测试
memtest() {

  _blue "2. 内存读取测试..."

  # 参数设置
  mem_size=1024 # 每次测试的数据块大小（MB）
  num_loops=100  # 循环次数

  # 开始测试内存读取速度
  start_time_mem=$(date +%s.%N)
  for ((i = 1; i <= num_loops; i++)); do
    dd if=/dev/zero of=/dev/null bs=$((1024 * 1024)) count=$mem_size >/dev/null 2>&1
  done
  end_time_mem=$(date +%s.%N)

  # 运算内存读取性能
  mem_read_time=$(echo "$end_time_mem - $start_time_mem" | bc)
  total_size=$(echo "$mem_size * $num_loops" | bc)                      # 总操作数据量
  mem_read_speed=$(echo "scale=2; ($total_size / $mem_read_time)" | bc) # 每秒读取MB
  mem_read_score=$(echo "scale=2; $mem_read_speed * 2" | bc)
  mem_read_score=$(awk '{print int($1)}' <<<"$mem_read_score")
  echo "内存读取速度：$mem_read_speed MB/s 得分：$mem_read_score"
}

#磁盘测试
disktest() {
  _blue "3. 磁盘读取测试..."
  # 获取所有块设备的详细信息
  disk_info=$(lsblk -o NAME,RM,TYPE)
  disk_devices=()
  # 逐行解析lsblk输出
  while IFS= read -r line; do
    # 跳过标题行
    if [[ $line == NAME* ]]; then
      continue
    fi
    device_name=$(echo $line | awk '{print $1}')
    device_type=$(echo $line | awk '{print $3}')
    if [[ $device_type == "disk" ]]; then
      disk_devices+=($device_name)
    fi
  done <<<"$disk_info"

  if [ ${#disk_devices[@]} -eq 0 ]; then
    echo "未找到磁盘设备"
    disk_score=0
    return 0
  fi

  # 选择第一个磁盘设备进行测试
  first_disk_device=${disk_devices[0]}
  start_time_disk=$(date +%s.%N)
  buffer=$(dd if=/dev/"$first_disk_device" of=/dev/null bs=1M count=4096 iflag=direct 2>/dev/null)
  end_time_disk=$(date +%s.%N)
  disk_time=$(echo "$end_time_disk - $start_time_disk" | bc)
  disk_speed=$(echo "scale=2; (4096 / $disk_time)" | bc)
  disk_score=$(echo "scale=2; $disk_speed * 80" | bc)

  disk_score=$(awk '{print int($1)}' <<<"$disk_score")
  echo "磁盘读取速度：$disk_speed Mb/s 得分：$disk_score"
  echo
}

# 主程序

#检查环境
environmentaltest

echo
_blue " _____         _   ____                  _     "
_blue "|  ___|_ _ ___| |_| __ )  ___ _ __   ___| |__  "
_blue "| |_ / _\` / __| __|  _ \ / _ \ '_ \ / __| '_ \ "
_blue "|  _| (_| \__ \ |_| |_) |  __/ | | | (__| | | |"
_blue "|_|  \__,_|___/\__|____/ \___|_| |_|\___|_| |_|"

echo
_green "CPU 型号：$cpu_model"
_green "CPU 主频：$cpu_freq MHz"
_green "CPU 核心数：$cpu_cores"
echo
_blue "1. CPU 测试..."
echo
# cpu测试
single_core_test
multi_core_test

multi_core_adjusted=$((multi_core_score * cpu_cores))
cpu_total_score=$((single_core_score + multi_core_adjusted))

#内存测试
memtest
#硬盘测试
disktest
# 计算总分
total_score=$((cpu_total_score + mem_read_score + disk_score))

# 展示结果
_yellow "==================== 测试结果 ===================="
echo "CPU 得分：$cpu_total_score (单核：$single_core_score 多核：$multi_core_adjusted)"
echo "内存得分：$mem_read_score"
echo "硬盘得分：$disk_score"
_green "总分数： $total_score"
_yellow "=================================================="
