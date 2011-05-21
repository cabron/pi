require 'strscan'

module Pi
	class Object
		attr_accessor :t, :v, :str, :arg, :c
		
		NUMBER = 0
		LABEL = 1
		
		OP = 2
			STREAM = 0
			POWER = 1
			SCOPE = 2
			EQ = 3
			NEQ = 4
			ADD = 5
			SUB = 6
			OR = 7
			AND = 8
			XOR = 9
			COMMA = 10
			LT = 11

		BRACKET = 3
			ROUND = 0
			SQUARE = 1
			CURLY = 2

			LEFT = 1024

		UNARY = 4
			AT = 0
			POINTER = 1
			INC = 2
			DEC = 3
		
		STRING = 5
		COMMENT = 6
		
		
		def initialize s=nil
			@arg = []
			@c = {}
			return if not s.is_a?(StringScanner)
			
			@pos = s.pos
			if s.check(/#!(.*)\n/) && s.pos == 0
				@t = COMMENT
				@str = s.scan(/#!(.*)\n/)
			elsif r = s.scan(/##\{([\s\S]*)\}|##(.*)\n/)
				@t = COMMENT
				@str = r
			elsif r = s.scan(/-?[0-9]+([0-9a-zA-Z_$xXoOhHrRbB]*)/)
				@t = NUMBER
				v = ''
				base = 10
				r.each_char {|c|
					if base == 10
						if 'hHxX$'[c]
							base = 16
						elsif 'oO'[c]
							base = 8
						elsif 'rR'[c]
							base = v.to_i
							v = ''
						else
							v += c
						end
					else
						v += c
					end
				}
				
				if base == 10 and (v['b'] or v['B'])
					r = v
					v = ''
					r.each_char {|c|
						if '01'[c]
							v += c
						elsif 'bB'[c]
							base = 2
						end
					}
				end
				
				#puts "NUMBER #{v}(#{base})"
				@v = v.to_i(base)
				
			elsif r = s.scan(/[a-zA-Z$_][a-zA-Z0-9$_]*/)
				@t = LABEL
				@v = r
			elsif r = s.scan(/[\(\)\[\]\{\}]/)
				@str = r
				@t = BRACKET
				@v = case r
					when '['..']' then	SQUARE
					when '('..')' then	ROUND
					when '{'..'}' then	CURLY
				end
				if ['[', '(', '{', '<'].include? r
					@v |= LEFT
				end
			elsif r = s.scan(/\+\+|--|@|->|!/)
				@str = r
				@t = UNARY
				@v = case r
					when '++' then INC
					when '--' then DEC
					when '@' then AT
					when '->' then POINTER
				end
			elsif r = s.scan(/<<|>>|\*\*|!=|::|\||&|\^|=|-|\+|,|.|<|>/)
				@str = r
				@t = OP
				@v = case r
					when ('<<' or '>>') then STREAM
					when '**' then POWER
					when '::' then SCOPE
					when '=' then EQ
					when '!=' then NEQ
					when '+' then ADD
					when '-' then SUB
					when '::' then SCOPE
					when '|' then OR
					when ',' then COMMA
					when ('<' or '>') then LT
				end
			elsif r = s.scan(/"[^"]*"/)
				@t = STRING
				@str = r
			end
		end

		def inspect
			case @t
				when NUMBER then @v
				when LABEL then @v
				when OP then @str
				when BRACKET then @str
				when UNARY then @str
				when STRING then @str
				when COMMENT then @str
			end
		end
	end
	
	class Lexer < StringScanner
		attr_accessor :a
		
		def initialize s
			@a = Object.new
			super s
			
			while !empty?
				@a.arg << Object.new(self)
				skip(/\s*/)
			end
		end
		
		def parse
			tree = []
			
			while not @a.arg.empty?
				tree << parse_re
			end
			
			@a.arg = tree
		end
		
		def parse_re
			p @a.arg.length
			t = @a.arg.slice! 0
			return nil if not t
			
			if t.t == Object::LABEL
				arg = parse_re	#x(arg)
				
				if not arg
					t.arg = []
				elsif arg.t == Object::OP
					arg.arg = [t, parse_re]
					return arg
				else
					t.arg = [arg]
				end
			elsif t.t == Object::BRACKET
				arg = t
				while true
					tmp = parse_re
					return arg if !tmp or (tmp.t == Object::BRACKET and tmp.t == arg.t)
					arg.arg << tmp
				end
			end
			
			return t
		end
		
		def compile
			@a.arg.map {|e|
				if e.t == Object::LABEL
					if not @a.c[e.v]
						raise "undefined `#{e.v}`"
					end
					next @a.c[e.v].c['execute'].arg.join
				end
			}.join
		end
		
		def to_html
			return '' if @a.arg.empty?
			"<ul>" + @a.arg.map {|t|
				"\t<li>#{t.to_html}</li>\n"
			}.join + "</ul>"
		end
	end

	def Pi.eval s #String/IO
		if s.is_a?(IO)
			s = s.read
		elsif !s.is_a?(String)
			raise if !(s = String.try_convert s)
		end

		3 #...
	end
end
