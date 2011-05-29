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
		
		
		def initialize
			@arg = []
			@c = {}
		end

		def inspect
			case @t
				when LABEL then @v
				when OP then @str
				when BRACKET then @str
				when UNARY then @str
				when COMMENT then @str
			end
		end
	end

	class Fixnum < Object
		def initialize n
			super *[]
			@v = n
		end

		def inspect; @v end
	end

	class PiString < Object
		def initialize s
			super *[]
			@str = s
		end

		def inspect; @str end
	end

	class Lexer < StringScanner
		attr_accessor :tokens
		
		def initialize s=''
			@tokens = []
			super s
			
			while !empty?
				@tokens << if check(/#!(.*)\n/) && pos == 0
					o = Object.new
					o.t = Object::COMMENT
					o.str = scan(/#!(.*)\n/)
				elsif r = scan(/##\{([\s\S]*)\}|##(.*)\n/)
					o = Object.new
					o.t = Object::COMMENT
					o.str = r
				elsif r = scan(/-?[0-9]+([0-9a-zA-Z_$xXoOhHrRbB]*)/)
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
					
					Pi::Fixnum.new v.to_i(base)
				elsif r = scan(/[a-zA-Z$_][a-zA-Z0-9$_]*/)
					o = Object.new
					o.t = Object::LABEL
					o.v = r
				elsif r = scan(/[\(\)\[\]\{\}]/)
					o = Object.new
					o.str = r
					o.t = Object::BRACKET
					o.v = case r
						when '['..']' then	Object::SQUARE
						when '('..')' then	Object::ROUND
						when '{'..'}' then	Object::CURLY
					end
					if ['[', '(', '{', '<'].include? r
						o.v |= Object::LEFT
					end
				elsif r = scan(/\+\+|--|@|->|!/)
					o = Object.new
					o.str = r
					o.t = Object::UNARY
					o.v = case r
						when '++' then Object::INC
						when '--' then Object::DEC
						when '@' then Object::AT
						when '->' then Object::POINTER
					end
				elsif r = scan(/<<|>>|\*\*|!=|::|\||&|\^|=|-|\+|,|.|<|>/)
					o = Object.new
					o.str = r
					o.t = Object::OP
					o.v = case r
						when ('<<' or '>>') then Object::STREAM
						when '**' then Object::POWER
						when '::' then Object::SCOPE
						when '=' then Object::EQ
						when '!=' then Object::NEQ
						when '+' then Object::ADD
						when '-' then Object::SUB
						when '::' then Object::SCOPE
						when '|' then Object::OR
						when ',' then Object::COMMA
						when ('<' or '>') then Object::LT
					end
				elsif r = scan(/"[^"]*"/)
					PiString.new r
				end

				skip(/\s*/)
			end
		end
	end

	class Parser
		def initialize tree
			@tree = tree
		end

		def parse
			t = []

			while not @tree.empty?
				t << parse_re
			end
			
			t
		end
		
		def parse_re
			p @tree.length
			t = @tree.slice! 0
			return nil if not t
			
			if t.t == Object::LABEL
				arg = parse_re
				
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
	end

	class Compiler
		def initialize

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
	end

	def Pi.eval s
		if s.is_a?(IO)
			s = s.read
		elsif !s.is_a?(String)
			raise if !(s = String.try_convert s)
		end

		parse(tokenize s)
		
	end

	def Pi.tokenize s
		if s.is_a?(IO)
			s = s.read
		elsif !s.is_a?(String)
			raise if !(s = String.try_convert s)
		end

		l = Lexer.new s
		l.tokens
	end

	def Pi.parse t
		p = Parser.new t
		p.parse
	end
end
