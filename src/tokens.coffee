
###

  (c) 2006 Douglas Crockford

  Produce an array of simple token objects from a string.
  A simple token object contains these members:
       type: 'name', 'string', 'number', 'operator'
       value: string or number value of the token
       from: index of first character of the token
       to: index of the last character + 1

  Comments of the // type are ignored.

  Operators are by default single characters. Multicharacter
  operators can be made by supplying a string of prefix and
  suffix characters.
  characters. For example,

       '<>+-&', '=>&:'

  will match any of these:

       <=  >>  >>>  <>  >=  +: -: &: &&: &&
###

#-----------------------------------------------------------------------------------------------------------
String::tokens = (prefix, suffix) ->
  ### TAINT modifies `String.prototype` ###

  #---------------------------------------------------------------------------------------------------------
  c       = undefined # The current character.
  from    = undefined # The index of the start of the token.
  i       = 0         # The index of the current character.
  length  = @length
  n       = undefined # The number value.
  q       = undefined # The quote character.
  str     = undefined # The string value.
  R       = []        # An array to hold the results.

  #---------------------------------------------------------------------------------------------------------
  make = (type, value) ->
    # Make a token object.
    type: type
    value: value
    from: from
    to: i

  #---------------------------------------------------------------------------------------------------------
  # Begin tokenization. If the source string is empty, return nothing.
  return  unless this

  # If prefix and suffix strings are not provided, supply defaults.
  prefix = '<>+-&'  if typeof prefix isnt 'string'
  suffix = '=>&:'  if typeof suffix isnt 'string'

  # Loop through this text, one character at a time.
  c = @charAt(i)
  while c
    from = i

    # Ignore whitespace.
    if c <= ' '
      i += 1
      c = @charAt(i)

    # name.
    else if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')
      str = c
      i += 1
      loop
        c = @charAt(i)
        if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or (c >= '0' and c <= '9') or c is '_'
          str += c
          i += 1
        else
          break
      R.push make('name', str)

    # number.

    # A number cannot start with a decimal point. It must start with a digit,
    # possibly '0'.
    else if c >= '0' and c <= '9'
      str = c
      i += 1

      # Look for more digits.
      loop
        c = @charAt(i)
        break  if c < '0' or c > '9'
        i += 1
        str += c

      # Look for a decimal fraction part.
      if c is '.'
        i += 1
        str += c
        loop
          c = @charAt(i)
          break  if c < '0' or c > '9'
          i += 1
          str += c

      # Look for an exponent part.
      if c is 'e' or c is 'E'
        i += 1
        str += c
        c = @charAt(i)
        if c is '-' or c is '+'
          i += 1
          str += c
          c = @charAt(i)
        make('number', str).error 'Bad exponent'  if c < '0' or c > '9'
        loop
          i += 1
          str += c
          c = @charAt(i)
          break unless c >= '0' and c <= '9'

      # Make sure the next character is not a letter.
      if c >= 'a' and c <= 'z'
        str += c
        i += 1
        make('number', str).error 'Bad number'

      # Convert the string value to a number. If it is finite, then it is a good
      # token.
      n = +str
      if isFinite(n)
        R.push make('number', n)
      else
        make('number', str).error 'Bad number'

    # string
    else if c is '\'' or c is '"'
      str = ''
      q = c
      i += 1
      loop
        c = @charAt(i)
        make('string', str).error (if c is '\n' or c is '\r' or c is '' then 'Unterminated string.' else 'Control character in string.'), make('', str)  if c < ' '

        # Look for the closing quote.
        break  if c is q

        # Look for escapement.
        if c is '\\'
          i += 1
          make('string', str).error 'Unterminated string'  if i >= length
          c = @charAt(i)
          switch c
            when 'b'
              c = '\b'
            when 'f'
              c = '\f'
            when 'n'
              c = '\n'
            when 'r'
              c = '\r'
            when 't'
              c = '\t'
            when 'u'
              make('string', str).error 'Unterminated string'  if i >= length
              c = parseInt(@substr(i + 1, 4), 16)
              make('string', str).error 'Unterminated string'  if not isFinite(c) or c < 0
              c = String.fromCharCode(c)
              i += 4
        str += c
        i += 1
      i += 1
      R.push make('string', str)
      c = @charAt(i)

    # comment.
    else if c is '/' and @charAt(i + 1) is '/'
      i += 1
      loop
        c = @charAt(i)
        break  if c is '\n' or c is '\r' or c is ''
        i += 1

    # combining
    else if prefix.indexOf(c) >= 0
      str = c
      i += 1
      loop
        c = @charAt(i)
        break  if i >= length or suffix.indexOf(c) < 0
        str += c
        i += 1
      R.push make('operator', str)

    # single-character operator
    else
      i += 1
      R.push make('operator', c)
      c = @charAt(i)
  return R
