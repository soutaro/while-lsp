module WhileLSP
  module SyntaxTree
    # function Foo($x, $y) { expr; expr; ... }
    FunctionDeclaration = Data.define(:name, :params, :body, :range)

    # $x = expr
    AssignStatement = Data.define(:name, :value, :range)

    # return expr;
    ReturnStatement = Data.define(:value, :range)

    # echo expr;
    EchoStatement = Data.define(:args, :range)

    # if (expr) { ... } else { ... }
    IfStatement = Data.define(:condition, :then_body, :else_body, :range)

    # while (expr) { ... }
    WhileStatement = Data.define(:condition, :body, :range)

    # Foo(expr, expr, ...)
    FunctionCallStatement = Data.define(:expr, :range)

    # expr + expr - expr
    Math3Expr = Data.define(:exprs, :range)

    # expr % expr
    Math2Expr = Data.define(:exprs, :range)

    # expr * expr / expr
    Math1Expr = Data.define(:exprs, :range)

    # expr == expr
    EqualExpr = Data.define(:left, :right, :range)

    # expr != expr
    NotEqualExpr = Data.define(:left, :right, :range)

    # expr < expr
    LtExpr = Data.define(:left, :right, :range)

    # expr <= expr
    LtEqExpr = Data.define(:left, :right, :range)

    # expr > expr2
    GtExpr = Data.define(:left, :right, :range)

    # expr >= expr
    GtEqExpr = Data.define(:left, :right, :range)

    # $x
    VarExpr = Data.define(:name, :range)

    # 123
    IntExpr = Data.define(:value, :range)

    # Foo(expr, expr, ...)
    FunctionCallExpr = Data.define(:name, :args, :range, :name_range)

    # PHP_EOL
    PHPEOLExpr = Data.define(:range)
  end
end
