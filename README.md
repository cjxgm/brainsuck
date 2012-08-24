# brainsuck - painlessly brainfucking
![bslogo](https://github.com/cjxgm/brainsuck/raw/master/image/bs.png "brainsuck")<hr>
by eXerigumo Clanjor (哆啦比猫/兰威举), 2012.<br>
Licensed under GPLv2.<br>
*ALPHA*<br>

# Components
It has 2 components: `llbs` and `bs`.

`llbs` stands for "**l**ow-**l**evel **b**rain**s**uck", it's an
assembly-like language. `bs` stands for "**b**rain**s**uck", it's a
high-level language just like `c` or whatever.

`bs` compiles source codes to `llbs`, and `llbs` then produces
`brainfuck` codes.

# Walkthrough
`recursive.bs`

```c
main									#0
{
	write (func 11);					#1
}

func x									#2
{
	if x {								#3
		return x + func(x-1);			#4
	}
	else return 0;						#5
}										#6
```

It will be compiled by `bs` into `llbs` code.

`recursive.llbs`

```asm
@#0
	push
	push	11
	go		2, 1

@#1
	pop
	write
	exit

@#2
	push	[1]
	if		3, 5, 6

@#3
	push	[2]
	push
	push	[4]
	push	1
	sub
	go		2, 4

@#4
	pop
	add
	pop		[3]

@#5
	push	0
	pop		[3]

@#6
```

Then, after compiled by `llbs`, it becomes something like this:

`recursive.b`

```brainfuck
>>>+[
	<[->-]>[-<<
	>
	>+++++++++++
	>+>++
	>->]<+[

	<[->-]>[-<<
	[-]<
	.[-]<
	>>>+<<<
	>->]<+[

	<[->-]>[-<<
	<[->>+>+<<<]>>>[-<<<+>>>]<
	[[-]>+<]+>[-<-++++++>+++>>]<[-++++++>+++++>]<
	>->]<+[

	<[->-]>[-<<
	<<[->>>+>+<<<<]>>>>[-<<<<+>>>>]<
	>
	<<<<[->>>>>+>+<<<<<<]>>>>>>[-<<<<<<+>>>>>>]<
	>+
	[-<->]<
	>++++>++
	>->]<+[

	<[->-]>[-<<
	[-]<
	[-<+>]<
	[-<<<<+>>>>]<
	>->]<+[

	<[->-]>[-<<
	>
	[-<<<<+>>>>]<
	>->]<+[

	<[->-]>[-<<
	>->]<+[
-]]]]]]]
+>>[-<<->>]<<]
```

And then, you can share this with friends after cleaning up the blanks by

```bash
awk '//{gsub(/\t/,"");printf$0}END{print""}' recursive.b
```

And you will get:

```brainfuck
>>>+[<[->-]>[-<<>>+++++++++++>+>++>->]<+[<[->-]>[-<<[-]<.[-]<>>>+<<<>->]<+[<[->-]>[-<<<[->>+>+<<<]>>>[-<<<+>>>]<[[-]>+<]+>[-<-++++++>+++>>]<[-++++++>+++++>]<>->]<+[<[->-]>[-<<<<[->>>+>+<<<<]>>>>[-<<<<+>>>>]<><<<<[->>>>>+>+<<<<<<]>>>>>>[-<<<<<<+>>>>>>]<>+[-<->]<>++++>++>->]<+[<[->-]>[-<<[-]<[-<+>]<[-<<<<+>>>>]<>->]<+[<[->-]>[-<<>[-<<<<+>>>>]<>->]<+[<[->-]>[-<<>->]<+[-]]]]]]]+>>[-<<->>]<<]
```

