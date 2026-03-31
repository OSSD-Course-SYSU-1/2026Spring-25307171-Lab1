# 示例数据
nums = [5, 2, 9, 1, 3]

# 方法一：使用内置 sorted()（不改变原列表）
sorted_nums = sorted(nums)
print("升序排序结果:", sorted_nums)

# 方法二：使用 list.sort()（会修改原列表）
nums.sort()
print("原列表排序后:", nums)

# 方法三：降序排序
sorted_desc = sorted(nums, reverse=True)
print("降序排序结果:", sorted_desc)

# 方法四：对字符串列表排序
words = ["banana", "apple", "orange"]
words.sort()
print("字符串排序:", words)

# 方法五：按自定义规则排序（例如按长度）
words.sort(key=lambda x: len(x))
print("按字符串长度排序:", words)