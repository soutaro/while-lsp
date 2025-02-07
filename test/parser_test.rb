require_relative "test_helper"

class ParserTest < Minitest::Test
  def test_parse_expr_int
    parser = WhileLSP::Parser.new("1")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of(WhileLSP::SyntaxTree::IntExpr, expr)
    assert_equal 1, expr.value
  end

  def test_parse_expr_phpeol
    parser = WhileLSP::Parser.new("PHP_EOL")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of(WhileLSP::SyntaxTree::PHPEOLExpr, expr)
  end

  def test_parse_expr_paren
    parser = WhileLSP::Parser.new("(1)")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of(WhileLSP::SyntaxTree::IntExpr, expr)
    assert_equal 1, expr.value
  end

  def test_parse_expr_var
    parser = WhileLSP::Parser.new("$xyz")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of(WhileLSP::SyntaxTree::VarExpr, expr)
    assert_equal "$xyz", expr.name
  end

  def test_parse_expr_funcall
    parser = WhileLSP::Parser.new("GCD(1, $x)")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of(WhileLSP::SyntaxTree::FunctionCallExpr, expr)
    assert_equal "GCD", expr.name
    assert_equal 2, expr.args.size

    assert_instance_of(WhileLSP::SyntaxTree::IntExpr, expr.args[0])
    assert_equal 1, expr.args[0].value

    assert_instance_of(WhileLSP::SyntaxTree::VarExpr, expr.args[1])
    assert_equal "$x", expr.args[1].name
  end

  def test_parse_expr_oprs
    parser = WhileLSP::Parser.new("1 + 2 - 3 * 4 / 5 % 6")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of WhileLSP::SyntaxTree::Math3Expr, expr
    assert_equal 5, expr.exprs.size

    expr.exprs[0].tap do |expr|
      assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr
      assert_equal 1, expr.value
    end
    assert_equal "+", expr.exprs[1]
    expr.exprs[2].tap do |expr|
      assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr
      assert_equal 2, expr.value
    end
    assert_equal "-", expr.exprs[3]
    expr.exprs[4].tap do |expr|
      assert_instance_of WhileLSP::SyntaxTree::Math2Expr, expr
      assert_equal 3, expr.exprs.size

      expr.exprs[0].tap do |expr|
        assert_instance_of WhileLSP::SyntaxTree::Math1Expr, expr
        assert_equal 5, expr.exprs.size

        expr.exprs[0].tap do |expr|
          assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr
          assert_equal 3, expr.value
        end
        assert_equal "*", expr.exprs[1]
        expr.exprs[2].tap do |expr|
          assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr
          assert_equal 4, expr.value
        end
        assert_equal "/", expr.exprs[3]
        expr.exprs[4].tap do |expr|
          assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr
          assert_equal 5, expr.value
        end
      end
      assert_equal "%", expr.exprs[1]
      expr.exprs[2].tap do |expr|
        assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr
        assert_equal 6, expr.value
      end
    end
  end

  def test_parse_expr_opr_gt
    parser = WhileLSP::Parser.new("$x > 1")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of WhileLSP::SyntaxTree::GtExpr, expr
    assert_instance_of WhileLSP::SyntaxTree::VarExpr, expr.left
    assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr.right
  end

  def test_parse_expr_opr_gteq
    parser = WhileLSP::Parser.new("$x >= 1")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of WhileLSP::SyntaxTree::GtEqExpr, expr
    assert_instance_of WhileLSP::SyntaxTree::VarExpr, expr.left
    assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr.right
  end

  def test_parse_expr_opr_lt
    parser = WhileLSP::Parser.new("$x < 1")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of WhileLSP::SyntaxTree::LtExpr, expr
    assert_instance_of WhileLSP::SyntaxTree::VarExpr, expr.left
    assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr.right
  end

  def test_parse_expr_opr_lteq
    parser = WhileLSP::Parser.new("$x <= 1")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of WhileLSP::SyntaxTree::LtEqExpr, expr
    assert_instance_of WhileLSP::SyntaxTree::VarExpr, expr.left
    assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr.right
  end

  def test_parse_expr_opr_eq
    parser = WhileLSP::Parser.new("$x == 1")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of WhileLSP::SyntaxTree::EqualExpr, expr
    assert_instance_of WhileLSP::SyntaxTree::VarExpr, expr.left
    assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr.right
  end

  def test_parse_expr_opr_neq
    parser = WhileLSP::Parser.new("$x != 1")
    parser.advance_token()

    expr = parser.parse_expr()

    assert_instance_of WhileLSP::SyntaxTree::NotEqualExpr, expr
    assert_instance_of WhileLSP::SyntaxTree::VarExpr, expr.left
    assert_instance_of WhileLSP::SyntaxTree::IntExpr, expr.right
  end

  def test_parse_statement_echo
    parser = WhileLSP::Parser.new("echo 1, 2;")
    parser.advance_token()

    statement = parser.parse_statement()

    assert_instance_of WhileLSP::SyntaxTree::EchoStatement, statement
    assert_equal 2, statement.args.size

    assert_instance_of WhileLSP::SyntaxTree::IntExpr, statement.args[0]
    assert_instance_of WhileLSP::SyntaxTree::IntExpr, statement.args[1]
  end

  def test_parse_statement_if
    parser = WhileLSP::Parser.new("if ($x) { echo 1; }")
    parser.advance_token()

    stmt = parser.parse_statement()

    assert_instance_of WhileLSP::SyntaxTree::IfStatement, stmt
    assert_equal 1, stmt.then_body.size
    assert_instance_of WhileLSP::SyntaxTree::EchoStatement, stmt.then_body[0]

    assert_equal 0, stmt.else_body.size
  end

  def test_statement_assign
    parser = WhileLSP::Parser.new("$x = $x - 1;")
    parser.advance_token()

    stmt = parser.parse_statement()

    assert_instance_of WhileLSP::SyntaxTree::AssignStatement, stmt
    assert_equal "$x", stmt.name
    assert_instance_of WhileLSP::SyntaxTree::Math3Expr, stmt.value
  end

  def test_parse_statement_if
    parser = WhileLSP::Parser.new("if ($x) { echo 1; } else { echo 2; }")
    parser.advance_token()

    stmt = parser.parse_statement()

    assert_instance_of WhileLSP::SyntaxTree::IfStatement, stmt
    assert_equal 1, stmt.then_body.size
    assert_instance_of WhileLSP::SyntaxTree::EchoStatement, stmt.then_body[0]

    assert_equal 1, stmt.else_body.size
    assert_instance_of WhileLSP::SyntaxTree::EchoStatement, stmt.else_body[0]
  end

  def test_parse_statement_if
    parser = WhileLSP::Parser.new("if ($x) { echo 1; } else { echo 2; }")
    parser.advance_token()

    stmt = parser.parse_statement()

    assert_instance_of WhileLSP::SyntaxTree::IfStatement, stmt
    assert_equal 1, stmt.then_body.size
    assert_instance_of WhileLSP::SyntaxTree::EchoStatement, stmt.then_body[0]

    assert_equal 1, stmt.else_body.size
    assert_instance_of WhileLSP::SyntaxTree::EchoStatement, stmt.else_body[0]
  end

  def test_parse_statement_while
    parser = WhileLSP::Parser.new("while ($x > 0) { $x = $x - 1; }")
    parser.advance_token()

    stmt = parser.parse_statement()

    assert_instance_of WhileLSP::SyntaxTree::WhileStatement, stmt
    assert_instance_of WhileLSP::SyntaxTree::GtExpr, stmt.condition
    assert_equal 1, stmt.body.size
    assert_instance_of WhileLSP::SyntaxTree::AssignStatement, stmt.body[0]
  end

  def test_parse_statement_return
    parser = WhileLSP::Parser.new("return 1;")
    parser.advance_token()

    stmt = parser.parse_statement()

    assert_instance_of WhileLSP::SyntaxTree::ReturnStatement, stmt
    assert_instance_of WhileLSP::SyntaxTree::IntExpr, stmt.value
  end

  def test_parse_function_decl
    parser = WhileLSP::Parser.new("function Add($x, $y) { return $x + $y; }")
    parser.advance_token()

    decl = parser.parse_function_decl()

    assert_instance_of WhileLSP::SyntaxTree::FunctionDeclaration, decl
    assert_equal "Add", decl.name
    assert_equal ["$x", "$y"], decl.params
    assert_equal 1, decl.body.size
    assert_instance_of WhileLSP::SyntaxTree::ReturnStatement, decl.body[0]
  end

  def test_parse_program
    parser = WhileLSP::Parser.new("function Add($x, $y) { return $x + $y; } echo Add(1, 2);")

    program = parser.parse()

    assert_equal 2, program.size
    assert_instance_of WhileLSP::SyntaxTree::FunctionDeclaration, program[0]
    assert_instance_of WhileLSP::SyntaxTree::EchoStatement, program[1]
  end
end
