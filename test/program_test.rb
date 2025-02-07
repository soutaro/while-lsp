require_relative "test_helper"

class ProgramTest < Minitest::Test
  def test__position
    program = WhileLSP::Program.new("uri")
    program.instance_variable_set("@src", <<-TEXT)
12345
12345
    TEXT

    assert_equal 0, program.position(0, 0)
    assert_equal 5, program.position(0, 5)
    assert_equal 6, program.position(1, 0)
    assert_equal 11, program.position(1, 5)
  end

  def test__line_char
    program = WhileLSP::Program.new("uri")
    program.instance_variable_set("@src", <<-TEXT)
12345
12345
    TEXT

    assert_equal [0, 0], program.line_char(0)
    assert_equal [0, 5], program.line_char(5)
    assert_equal [1, 0], program.line_char(6)
    assert_equal [1, 5], program.line_char(11)
  end
end
