module WhileLSP
  class Program
    attr_reader :uri

    # ソースコードのテキスト
    attr_reader :src

    # 構文木
    attr_reader :syntax

    attr_reader :typechecker

    def initialize(uri)
      @uri = uri
      @diagnostics = []
    end

    def update(text)
      @src = text.dup
      begin
        program = Parser.new(src).parse()
        @syntax = program

        typechecker = TypeChecker.new(program)
        typechecker.type_check()
        @typechecker = typechecker
      rescue Parser::Error => exn
        @syntax = exn
        @typechecker = nil
      end
    end

    def diagnostics
      case
      when syntax.is_a?(Parser::Error)
        [[syntax.range, "PARSER", syntax.message]]
      when typechecker
        typechecker.diagnostics
      else
        nil
      end
    end

    # Returns the character position from (zero-origin) line and character
    #
    def position(line, character)
      pre_lines = src.each_line.take(line)
      pre_lines.sum {|line| line.size } + character
    end

    # Returns the pair of 0-origin line and character from the character position
    #
    def line_char(position)
      leading_lines = src.each_line.take_while do |line|
        if position >= line.size
          position -= line.size
          true
        end
      end

      [leading_lines.size, position]
    end

    def locate_syntax(position)
      return unless syntax
      return if syntax.is_a?(Parser::Error)

      syntax.each do |decl|
        if decl.is_a?(SyntaxTree::FunctionDeclaration)
          if located = locate_function(position, decl)
            return located
          end
        else
          if located = locate_statement(position, decl)
            return located
          end
        end
      end

      nil
    end

    def locate_function(position, decl)
      if decl.range.cover?(position)
        decl.body.each do |stmt|
          if located = locate_statement(position, stmt)
            return located
          end
        end

        decl
      end
    end

    def locate_statement(position, stmt)
      if stmt.range.cover?(position)
        # @type var located: SyntaxTree::statement | SyntaxTree::expr | nil

        case stmt
        when SyntaxTree::AssignStatement, SyntaxTree::ReturnStatement
          if located = locate_expr(position, stmt.value)
            return located
          end
        when SyntaxTree::EchoStatement
          stmt.args.each do |arg|
            if located = locate_expr(position, arg)
              return located
            end
          end
        when SyntaxTree::IfStatement
          if located = locate_expr(position, stmt.condition)
            return located
          end

          (stmt.then_body + stmt.else_body).each do |stmt|
            if located = locate_statement(position, stmt)
              return located
            end
          end
        when SyntaxTree::WhileStatement
          if located = locate_expr(position, stmt.condition)
            return located
          end

          stmt.body.each do |stmt|
            if located = locate_statement(position, stmt)
              return located
            end
          end
        end

        stmt
      end
    end

    def locate_expr(position, expr)
      if expr.range.cover?(position)
        case expr
        when SyntaxTree::VarExpr, SyntaxTree::IntExpr, SyntaxTree::PHPEOLExpr
          # nop
        when SyntaxTree::FunctionCallExpr
          expr.args.each do |arg|
            if located = locate_expr(position, arg)
              return located
            end
          end
        when SyntaxTree::Math3Expr, SyntaxTree::Math2Expr, SyntaxTree::Math1Expr
          expr.exprs.each do |subexpr|
            next if subexpr.is_a?(String)
            if located = locate_expr(position, subexpr)
              return located
            end
          end
        when SyntaxTree::GtEqExpr, SyntaxTree::GtExpr, SyntaxTree::LtEqExpr, SyntaxTree::LtExpr, SyntaxTree::EqualExpr, SyntaxTree::NotEqualExpr
          if located = locate_expr(position, expr.left)
            return located
          end
          if located = locate_expr(position, expr.right)
            return located
          end
        end

        expr
      end
    end
  end
end
