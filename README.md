

- [TDOP](#tdop)
	- [Usage](#usage)

> **Table of Contents**  *generated with [DocToc](http://doctoc.herokuapp.com/)*


# TDOP

> https://github.com/douglascrockford/TDOP adapted for NodeJS

**Note** This is work in progress and probably not very usable for a lot of people.

## Usage

Currently

> **Note** you may want to check out an older commit like [cd4b646](https://github.com/loveencounterflow/tdop/commit/cd4b6466ebc847e5859ec47944f9df7bd34f8bbd)
> to make sure the below description works as advertised.


```coffee
# module exports a function that returns a parser:
new_parse = require 'tdop'
parse 		= new_parse()

info parse 'var a = 1 + 1;'
info parse """
  var f = function(){};
  var x = f(8);"""
```

