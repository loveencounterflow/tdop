
###
  parse.js
  Parser for Simplified JavaScript written in Simplified JavaScript
  From Top Down Operator Precedence
  http://javascript.crockford.com/tdop/index.html
  Douglas Crockford
  2010-06-26
###


############################################################################################################
TRM                       = require 'coffeenode-trm'
rpr                       = TRM.rpr.bind TRM
badge                     = 'TDOP'
# log                       = TRM.get_logger 'plain',   badge
# info                      = TRM.get_logger 'info',    badge
# alert                     = TRM.get_logger 'alert',   badge
debug                     = TRM.get_logger 'debug',   badge
warn                      = TRM.get_logger 'warn',    badge
# urge                      = TRM.get_logger 'urge',    badge
# whisper                   = TRM.get_logger 'whisper', badge
# help                      = TRM.get_logger 'help',    badge
# echo                      = TRM.echo.bind TRM
#...........................................................................................................
### TAINT modifies `String.prototype` ###
### TAINT do we want to have a separate tokenizer? ###
require './tokens'

#===========================================================================================================
make_parse = ->
  scope         = null
  symbol_table  = {}
  token         = null
  tokens        = null
  token_nr      = null
  itself        = -> @

  #---------------------------------------------------------------------------------------------------------
  original_scope =
    define: (n) ->
      t = @def[n.value]
      n.error (if t.reserved then 'Already reserved.' else 'Already defined.')  if typeof t is 'object'
      @def[n.value] = n
      n.reserved = false
      n.nud = itself
      n.led = null
      n.std = null
      n.lbp = 0
      n.scope = scope
      n

    find: (n) ->
      e = this
      o = null
      loop
        o = e.def[n]
        return e.def[n]  if o and typeof o isnt 'function'
        e = e.parent
        unless e
          o = symbol_table[n]
          return (if o and typeof o isnt 'function' then o else symbol_table['(name)'])
      return

    pop: ->
      scope = @parent
      return

    reserve: (n) ->
      return  if n.arity isnt 'name' or n.reserved
      t = @def[n.value]
      if t
        return  if t.reserved
        n.error 'Already defined.'  if t.arity is 'name'
      @def[n.value] = n
      n.reserved = true
      return

  #---------------------------------------------------------------------------------------------------------
  new_scope = ->
    s = scope
    scope = Object.create(original_scope)
    scope.def = {}
    scope.parent = s
    return scope

  #---------------------------------------------------------------------------------------------------------
  advance = (id) ->
    a = null
    o = null
    t = null
    v = null
    #.......................................................................................................
    token.error 'Expected \'' + id + '\'.'  if id and token.id isnt id
    #.......................................................................................................
    if token_nr >= tokens.length
      token = symbol_table['(end)']
      return
    #.......................................................................................................
    t         = tokens[token_nr]
    token_nr += 1
    v         = t.value
    a         = t.type
    #.......................................................................................................
    switch a
      #.....................................................................................................
      when 'name'
        o = scope.find(v)
      #.....................................................................................................
      when 'operator'
        o = symbol_table[v]
        t.error 'Unknown operator.'  unless o
      #.....................................................................................................
      when 'string', 'number'
        o = symbol_table['(literal)']
        a = 'literal'
      #.....................................................................................................
      else
        t.error "Unexpected token #{rpr t}"
    #.......................................................................................................
    token = Object.create(o)
    token.from = t.from
    token.to = t.to
    token.value = v
    token.arity = a
    return token

  #---------------------------------------------------------------------------------------------------------
  expression = (rbp) ->
    left = null
    t = token
    advance()
    left = t.nud()
    while rbp < token.lbp
      t = token
      advance()
      left = t.led(left)
    left

  #---------------------------------------------------------------------------------------------------------
  statement = ->
    n = token
    v = null
    if n.std
      advance()
      scope.reserve n
      return n.std()
    v = expression(0)
    v.error 'Bad expression statement.'  if not v.assignment and v.id isnt '('
    advance ';'
    v

  #---------------------------------------------------------------------------------------------------------
  statements = ->
    a = []
    s = null
    loop
      break  if token.id is '}' or token.id is '(end)'
      s = statement()
      a.push s  if s
    (if a.length is 0 then null else (if a.length is 1 then a[0] else a))

  #---------------------------------------------------------------------------------------------------------
  block = ->
    t = token
    advance '{'
    t.std()

  #---------------------------------------------------------------------------------------------------------
  original_symbol =

    #.......................................................................................................
    error: (message) ->
      # console.log( '!!!' + message );
      throw new Error(message)

    #.......................................................................................................
    nud: ->
      @error "doesn't have a nud: #{rpr @}"
      return

    #.......................................................................................................
    led: (left) ->
      @error "Missing operator / led: #{rpr @}"
      return

  #---------------------------------------------------------------------------------------------------------
  symbol = (id, bp) ->
    s   = symbol_table[id]
    bp  = bp or 0
    #.......................................................................................................
    if s
      s.lbp = bp  if bp >= s.lbp
    #.......................................................................................................
    else
      s = Object.create(original_symbol)
      s.id = s.value = id
      s.lbp = bp
      symbol_table[id] = s
    #.......................................................................................................
    return s

  #---------------------------------------------------------------------------------------------------------
  constant = (s, v) ->
    x = symbol(s)
    #.......................................................................................................
    x.nud = ->
      scope.reserve this
      @value = symbol_table[@id].value
      @arity = 'literal'
      this
    #.......................................................................................................
    x.value = v
    return x

  #---------------------------------------------------------------------------------------------------------
  infix = (id, bp, led) ->
    s = symbol(id, bp)
    #.......................................................................................................
    s.led = led or (left) ->
      @first = left
      @second = expression(bp)
      @arity = 'binary'
      this
    #.......................................................................................................
    return s

  #---------------------------------------------------------------------------------------------------------
  infixr = (id, bp, led) ->
    s = symbol(id, bp)
    #.......................................................................................................
    s.led = led or (left) ->
      @first = left
      @second = expression(bp - 1)
      @arity = 'binary'
      this
    #.......................................................................................................
    return s

  #---------------------------------------------------------------------------------------------------------
  assignment = (id) ->
    return infixr id, 10, (left) ->
      left.error 'Bad lvalue.'  if left.id isnt '.' and left.id isnt '[' and left.arity isnt 'name'
      @first = left
      @second = expression(9)
      @assignment = true
      @arity = 'binary'
      return @

  #---------------------------------------------------------------------------------------------------------
  prefix = (id, nud) ->
    s = symbol(id)
    s.nud = nud or ->
      scope.reserve this
      @first = expression(70)
      @arity = 'unary'
      return @
    #.......................................................................................................
    return s

  #---------------------------------------------------------------------------------------------------------
  stmt = (s, f) ->
    x = symbol(s)
    x.std = f
    return x

  symbol '(end)'
  symbol '(name)'
  symbol ':'
  symbol ';'
  symbol ')'
  symbol ']'
  symbol '}'
  symbol ','
  symbol 'else'
  constant 'true', true
  constant 'false', false
  constant 'null', null
  constant 'pi', 3.141592653589793
  constant 'Object', {}
  constant 'Array', []
  symbol('(literal)').nud = itself
  symbol('this').nud = ->
    scope.reserve this
    @arity = 'this'
    return @

  assignment '='
  assignment '+='
  assignment '-='
  infix '?', 20, (left) ->
    @first = left
    @second = expression(0)
    advance ':'
    @third = expression(0)
    @arity = 'ternary'
    return @

  infixr '&&', 30
  infixr '||', 30
  infixr '===', 40
  infixr '!==', 40
  infixr '<', 40
  infixr '<=', 40
  infixr '>', 40
  infixr '>=', 40
  infix '+', 50
  infix '-', 50
  infix '*', 60
  infix '/', 60
  infix '.', 80, (left) ->
    @first = left
    token.error 'Expected a property name.'  if token.arity isnt 'name'
    token.arity = 'literal'
    @second = token
    @arity = 'binary'
    advance()
    return @

  infix '[', 80, (left) ->
    @first = left
    @second = expression(0)
    @arity = 'binary'
    advance ']'
    return @

  infix '(', 80, (left) ->
    a = []
    if left.id is '.' or left.id is '['
      @arity = 'ternary'
      @first = left.first
      @second = left.second
      @third = a
    else
      @arity = 'binary'
      @first = left
      @second = a
      left.error 'Expected a variable name.'  if (left.arity isnt 'unary' or left.id isnt 'function') and left.arity isnt 'name' and left.id isnt '(' and left.id isnt '&&' and left.id isnt '||' and left.id isnt '?'
    if token.id isnt ')'
      loop
        a.push expression(0)
        break  if token.id isnt ','
        advance ','
    advance ')'
    return @

  prefix '!'
  prefix '-'
  prefix 'typeof'
  prefix '(', ->
    e = expression(0)
    advance ')'
    e

  prefix 'function', ->
    a = []
    new_scope()
    if token.arity is 'name'
      scope.define token
      @name = token.value
      advance()
    advance '('
    if token.id isnt ')'
      loop
        token.error 'Expected a parameter name.'  if token.arity isnt 'name'
        scope.define token
        a.push token
        advance()
        break  if token.id isnt ','
        advance ','
    @first = a
    advance ')'
    advance '{'
    @second = statements()
    advance '}'
    @arity = 'function'
    scope.pop()
    return @

  prefix '[', ->
    a = []
    if token.id isnt ']'
      loop
        a.push expression(0)
        break  if token.id isnt ','
        advance ','
    advance ']'
    @first = a
    @arity = 'unary'
    return @

  prefix '{', ->
    a = []
    n = null
    v = null
    if token.id isnt '}'
      loop
        n = token
        token.error 'Bad property name.'  if n.arity isnt 'name' and n.arity isnt 'literal'
        advance()
        advance ':'
        v = expression(0)
        v.key = n.value
        a.push v
        break  if token.id isnt ','
        advance ','
    advance '}'
    @first = a
    @arity = 'unary'
    return @

  stmt '{', ->
    new_scope()
    a = statements()
    advance '}'
    scope.pop()
    a

  stmt 'var', ->
    a = []
    n = null
    t = null
    loop
      n = token
      n.error 'Expected a new variable name.'  if n.arity isnt 'name'
      scope.define n
      advance()
      if token.id is '='
        t = token
        advance '='
        t.first = n
        t.second = expression(0)
        t.arity = 'binary'
        a.push t
      break  if token.id isnt ','
      advance ','
    advance ';'
    (if a.length is 0 then null else (if a.length is 1 then a[0] else a))

  stmt 'if', ->
    advance '('
    @first = expression(0)
    advance ')'
    @second = block()
    if token.id is 'else'
      scope.reserve token
      advance 'else'
      @third = (if token.id is 'if' then statement() else block())
    else
      @third = null
    @arity = 'statement'
    return @

  stmt 'return', ->
    @first = expression(0)  if token.id isnt ';'
    advance ';'
    token.error 'Unreachable statement.'  if token.id isnt '}'
    @arity = 'statement'
    return @

  stmt 'break', ->
    advance ';'
    token.error 'Unreachable statement.'  if token.id isnt '}'
    @arity = 'statement'
    return @

  stmt 'while', ->
    advance '('
    @first = expression(0)
    advance ')'
    @second = block()
    @arity = 'statement'
    return @

  #---------------------------------------------------------------------------------------------------------
  return parse = ( source ) ->
    tokens = source.tokens('=<>!+-*&|/%^', '=<>&|')
    token_nr = 0
    new_scope()
    advance()
    s = statements()
    advance '(end)'
    scope.pop()
    return s

module.exports = make_parse # ()
