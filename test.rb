#!/usr/bin/env ruby1.9.1

$: << '.'
require 'libpi.rb'
require 'test/unit'

class LexerTest < Test::Unit::TestCase
	def test_lexer
		assert_equal(Pi.eval("1+2"), 3)
		assert_raise(RuntimeError) {Pi.eval []}
	end
end
