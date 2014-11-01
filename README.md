

- [TDOP](#tdop)
	- [Usage](#usage)

> **Table of Contents**  *generated with [DocToc](http://doctoc.herokuapp.com/)*


# TDOP

> https://github.com/douglascrockford/TDOP adapted for NodeJS

**Note** This is work in progress and probably not very usable for a lot of people.

## Usage


> **Note** you may want to check out an older commit like [cd4b646](https://github.com/loveencounterflow/tdop/commit/cd4b6466ebc847e5859ec47944f9df7bd34f8bbd)
> to make sure the below description works as advertised.

Currently the code only parses D. Crockford's Simplified JavaScript Syntax:

```coffee
# module exports a function that returns a parser:
new_parse = require 'tdop'
parse 		= new_parse()

console.log parse 'var a = 1 + 1;'
console.log parse """
  var f = function(){};
  var x = f(8);"""
```

Interestingly, just trying to compile a program like `f();` or `1 + 1;` results in compile-time errors
since in the first case, `f` is not defined, and in the second, the expression has no effect whatsover
(except taking some time to compute). Likewise, unreachable statements (e.g. code in a function body that
comes after a `return` statement on the same level) produce errors.

