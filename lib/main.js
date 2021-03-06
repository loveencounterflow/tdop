// Generated by CoffeeScript 1.8.0

/*
  parse.js
  Parser for Simplified JavaScript written in Simplified JavaScript
  From Top Down Operator Precedence
  http://javascript.crockford.com/tdop/index.html
  Douglas Crockford
  2010-06-26
 */

(function() {
  var TRM, badge, debug, make_parse, rpr, warn;

  TRM = require('coffeenode-trm');

  rpr = TRM.rpr.bind(TRM);

  badge = 'TDOP';

  debug = TRM.get_logger('debug', badge);

  warn = TRM.get_logger('warn', badge);


  /* TAINT modifies `String.prototype` */


  /* TAINT do we want to have a separate tokenizer? */

  require('./tokens');

  make_parse = function() {
    var advance, assignment, block, constant, expression, infix, infixr, itself, new_scope, original_scope, original_symbol, parse, prefix, scope, statement, statements, stmt, symbol, symbol_table, token, token_nr, tokens;
    scope = null;
    symbol_table = {};
    token = null;
    tokens = null;
    token_nr = null;
    itself = function() {
      return this;
    };
    original_scope = {
      define: function(n) {
        var t;
        t = this.def[n.value];
        if (typeof t === 'object') {
          n.error((t.reserved ? 'Already reserved.' : 'Already defined.'));
        }
        this.def[n.value] = n;
        n.reserved = false;
        n.nud = itself;
        n.led = null;
        n.std = null;
        n.lbp = 0;
        n.scope = scope;
        return n;
      },
      find: function(n) {
        var e, o;
        e = this;
        o = null;
        while (true) {
          o = e.def[n];
          if (o && typeof o !== 'function') {
            return e.def[n];
          }
          e = e.parent;
          if (!e) {
            o = symbol_table[n];
            return (o && typeof o !== 'function' ? o : symbol_table['(name)']);
          }
        }
      },
      pop: function() {
        scope = this.parent;
      },
      reserve: function(n) {
        var t;
        if (n.arity !== 'name' || n.reserved) {
          return;
        }
        t = this.def[n.value];
        if (t) {
          if (t.reserved) {
            return;
          }
          if (t.arity === 'name') {
            n.error('Already defined.');
          }
        }
        this.def[n.value] = n;
        n.reserved = true;
      }
    };
    new_scope = function() {
      var s;
      s = scope;
      scope = Object.create(original_scope);
      scope.def = {};
      scope.parent = s;
      return scope;
    };
    advance = function(id) {
      var a, o, t, v;
      a = null;
      o = null;
      t = null;
      v = null;
      if (id && token.id !== id) {
        token.error('Expected \'' + id + '\'.');
      }
      if (token_nr >= tokens.length) {
        token = symbol_table['(end)'];
        return;
      }
      t = tokens[token_nr];
      token_nr += 1;
      v = t.value;
      a = t.type;
      switch (a) {
        case 'name':
          o = scope.find(v);
          break;
        case 'operator':
          o = symbol_table[v];
          if (!o) {
            t.error('Unknown operator.');
          }
          break;
        case 'string':
        case 'number':
          o = symbol_table['(literal)'];
          a = 'literal';
          break;
        default:
          t.error("Unexpected token " + (rpr(t)));
      }
      token = Object.create(o);
      token.from = t.from;
      token.to = t.to;
      token.value = v;
      token.arity = a;
      return token;
    };
    expression = function(rbp) {
      var left, t;
      left = null;
      t = token;
      advance();
      left = t.nud();
      while (rbp < token.lbp) {
        t = token;
        advance();
        left = t.led(left);
      }
      return left;
    };
    statement = function() {
      var n, v;
      n = token;
      v = null;
      if (n.std) {
        advance();
        scope.reserve(n);
        return n.std();
      }
      v = expression(0);
      if (!v.assignment && v.id !== '(') {
        v.error('Bad expression statement.');
      }
      advance(';');
      return v;
    };
    statements = function() {
      var a, s;
      a = [];
      s = null;
      while (true) {
        if (token.id === '}' || token.id === '(end)') {
          break;
        }
        s = statement();
        if (s) {
          a.push(s);
        }
      }
      if (a.length === 0) {
        return null;
      } else {
        if (a.length === 1) {
          return a[0];
        } else {
          return a;
        }
      }
    };
    block = function() {
      var t;
      t = token;
      advance('{');
      return t.std();
    };
    original_symbol = {
      error: function(message) {
        throw new Error(message);
      },
      nud: function() {
        this.error("doesn't have a nud: " + (rpr(this)));
      },
      led: function(left) {
        this.error("Missing operator / led: " + (rpr(this)));
      }
    };
    symbol = function(id, bp) {
      var s;
      s = symbol_table[id];
      bp = bp || 0;
      if (s) {
        if (bp >= s.lbp) {
          s.lbp = bp;
        }
      } else {
        s = Object.create(original_symbol);
        s.id = s.value = id;
        s.lbp = bp;
        symbol_table[id] = s;
      }
      return s;
    };
    constant = function(s, v) {
      var x;
      x = symbol(s);
      x.nud = function() {
        scope.reserve(this);
        this.value = symbol_table[this.id].value;
        this.arity = 'literal';
        return this;
      };
      x.value = v;
      return x;
    };
    infix = function(id, bp, led) {
      var s;
      s = symbol(id, bp);
      s.led = led || function(left) {
        this.first = left;
        this.second = expression(bp);
        this.arity = 'binary';
        return this;
      };
      return s;
    };
    infixr = function(id, bp, led) {
      var s;
      s = symbol(id, bp);
      s.led = led || function(left) {
        this.first = left;
        this.second = expression(bp - 1);
        this.arity = 'binary';
        return this;
      };
      return s;
    };
    assignment = function(id) {
      return infixr(id, 10, function(left) {
        if (left.id !== '.' && left.id !== '[' && left.arity !== 'name') {
          left.error('Bad lvalue.');
        }
        this.first = left;
        this.second = expression(9);
        this.assignment = true;
        this.arity = 'binary';
        return this;
      });
    };
    prefix = function(id, nud) {
      var s;
      s = symbol(id);
      s.nud = nud || function() {
        scope.reserve(this);
        this.first = expression(70);
        this.arity = 'unary';
        return this;
      };
      return s;
    };
    stmt = function(s, f) {
      var x;
      x = symbol(s);
      x.std = f;
      return x;
    };
    symbol('(end)');
    symbol('(name)');
    symbol(':');
    symbol(';');
    symbol(')');
    symbol(']');
    symbol('}');
    symbol(',');
    symbol('else');
    constant('true', true);
    constant('false', false);
    constant('null', null);
    constant('pi', 3.141592653589793);
    constant('Object', {});
    constant('Array', []);
    symbol('(literal)').nud = itself;
    symbol('this').nud = function() {
      scope.reserve(this);
      this.arity = 'this';
      return this;
    };
    assignment('=');
    assignment('+=');
    assignment('-=');
    infix('?', 20, function(left) {
      this.first = left;
      this.second = expression(0);
      advance(':');
      this.third = expression(0);
      this.arity = 'ternary';
      return this;
    });
    infixr('&&', 30);
    infixr('||', 30);
    infixr('===', 40);
    infixr('!==', 40);
    infixr('<', 40);
    infixr('<=', 40);
    infixr('>', 40);
    infixr('>=', 40);
    infix('+', 50);
    infix('-', 50);
    infix('*', 60);
    infix('/', 60);
    infix('.', 80, function(left) {
      this.first = left;
      if (token.arity !== 'name') {
        token.error('Expected a property name.');
      }
      token.arity = 'literal';
      this.second = token;
      this.arity = 'binary';
      advance();
      return this;
    });
    infix('[', 80, function(left) {
      this.first = left;
      this.second = expression(0);
      this.arity = 'binary';
      advance(']');
      return this;
    });
    infix('(', 80, function(left) {
      var a;
      a = [];
      if (left.id === '.' || left.id === '[') {
        this.arity = 'ternary';
        this.first = left.first;
        this.second = left.second;
        this.third = a;
      } else {
        this.arity = 'binary';
        this.first = left;
        this.second = a;
        if ((left.arity !== 'unary' || left.id !== 'function') && left.arity !== 'name' && left.id !== '(' && left.id !== '&&' && left.id !== '||' && left.id !== '?') {
          left.error('Expected a variable name.');
        }
      }
      if (token.id !== ')') {
        while (true) {
          a.push(expression(0));
          if (token.id !== ',') {
            break;
          }
          advance(',');
        }
      }
      advance(')');
      return this;
    });
    prefix('!');
    prefix('-');
    prefix('typeof');
    prefix('(', function() {
      var e;
      e = expression(0);
      advance(')');
      return e;
    });
    prefix('function', function() {
      var a;
      a = [];
      new_scope();
      if (token.arity === 'name') {
        scope.define(token);
        this.name = token.value;
        advance();
      }
      advance('(');
      if (token.id !== ')') {
        while (true) {
          if (token.arity !== 'name') {
            token.error('Expected a parameter name.');
          }
          scope.define(token);
          a.push(token);
          advance();
          if (token.id !== ',') {
            break;
          }
          advance(',');
        }
      }
      this.first = a;
      advance(')');
      advance('{');
      this.second = statements();
      advance('}');
      this.arity = 'function';
      scope.pop();
      return this;
    });
    prefix('[', function() {
      var a;
      a = [];
      if (token.id !== ']') {
        while (true) {
          a.push(expression(0));
          if (token.id !== ',') {
            break;
          }
          advance(',');
        }
      }
      advance(']');
      this.first = a;
      this.arity = 'unary';
      return this;
    });
    prefix('{', function() {
      var a, n, v;
      a = [];
      n = null;
      v = null;
      if (token.id !== '}') {
        while (true) {
          n = token;
          if (n.arity !== 'name' && n.arity !== 'literal') {
            token.error('Bad property name.');
          }
          advance();
          advance(':');
          v = expression(0);
          v.key = n.value;
          a.push(v);
          if (token.id !== ',') {
            break;
          }
          advance(',');
        }
      }
      advance('}');
      this.first = a;
      this.arity = 'unary';
      return this;
    });
    stmt('{', function() {
      var a;
      new_scope();
      a = statements();
      advance('}');
      scope.pop();
      return a;
    });
    stmt('var', function() {
      var a, n, t;
      a = [];
      n = null;
      t = null;
      while (true) {
        n = token;
        if (n.arity !== 'name') {
          n.error('Expected a new variable name.');
        }
        scope.define(n);
        advance();
        if (token.id === '=') {
          t = token;
          advance('=');
          t.first = n;
          t.second = expression(0);
          t.arity = 'binary';
          a.push(t);
        }
        if (token.id !== ',') {
          break;
        }
        advance(',');
      }
      advance(';');
      if (a.length === 0) {
        return null;
      } else {
        if (a.length === 1) {
          return a[0];
        } else {
          return a;
        }
      }
    });
    stmt('if', function() {
      advance('(');
      this.first = expression(0);
      advance(')');
      this.second = block();
      if (token.id === 'else') {
        scope.reserve(token);
        advance('else');
        this.third = (token.id === 'if' ? statement() : block());
      } else {
        this.third = null;
      }
      this.arity = 'statement';
      return this;
    });
    stmt('return', function() {
      if (token.id !== ';') {
        this.first = expression(0);
      }
      advance(';');
      if (token.id !== '}') {
        token.error('Unreachable statement.');
      }
      this.arity = 'statement';
      return this;
    });
    stmt('break', function() {
      advance(';');
      if (token.id !== '}') {
        token.error('Unreachable statement.');
      }
      this.arity = 'statement';
      return this;
    });
    stmt('while', function() {
      advance('(');
      this.first = expression(0);
      advance(')');
      this.second = block();
      this.arity = 'statement';
      return this;
    });
    return parse = function(source) {
      var s;
      tokens = source.tokens('=<>!+-*&|/%^', '=<>&|');
      token_nr = 0;
      new_scope();
      advance();
      s = statements();
      advance('(end)');
      scope.pop();
      return s;
    };
  };

  module.exports = make_parse;

}).call(this);
