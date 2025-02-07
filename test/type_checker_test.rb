require_relative "test_helper"

class TypeCheckerTest < Minitest::Test
  def test__test
    parser = WhileLSP::Parser.new(<<~TEXT)
      function Add($x, $y) {
        return $x + $y + $z;
      }

      echo Add(1, 2, 3);
    TEXT
    program = parser.parse()

    type_checker = WhileLSP::TypeChecker.new(program)
    type_checker.type_check()

    pp type_checker.diagnostics()
  end
end
