module WhileLSP
  class TypeChecker
    Function = Data.define(:name, :params, :env, :body, :range)

    attr_reader :functions

    attr_reader :toplevel

    attr_reader :toplevel_env

    attr_reader :diagnostics

    def initialize(program)
      @functions = {}
      @toplevel_env = {}
      @diagnostics = []

      program.each do |decl|
        if decl.is_a?(SyntaxTree::FunctionDeclaration)
          functions[decl.name] = Function.new(decl.name, decl.params, {}, decl.body, decl.range)
        end
      end

      @toplevel = program.filter_map do |decl|
        unless decl.is_a?(SyntaxTree::FunctionDeclaration)
          decl
        end
      end
    end

    def type_check
      functions.each_value do |function|
        type_check_function(function)
      end

      type_check_statement(toplevel, toplevel_env)
    end

    def type_check_function(function)
      function.params.each do |param|
        function.env[param] = :int
      end

      type_check_statement(function.body, function.env)
    end

    def type_check_statement(stmts, env)
      current_env = env

      stmts.each do |stmt|
        case stmt
        when SyntaxTree::AssignStatement
          type = type_check_expr(stmt.value, current_env)
          current_env = current_env.merge(stmt.name => type)

        when SyntaxTree::ReturnStatement
          type_check_expr(stmt.value, current_env)

        when SyntaxTree::EchoStatement
          stmt.args.each do |arg|
            type_check_expr(arg, current_env)
          end

        when SyntaxTree::IfStatement
          type_check_expr(stmt.condition, current_env)
          then_env = type_check_statement(stmt.then_body, current_env.dup)
          else_env = type_check_statement(stmt.else_body, current_env.dup)

          current_env = merge_env(then_env, else_env)

        when SyntaxTree::WhileStatement
          type_check_expr(stmt.condition, current_env)
          body_env = type_check_statement(stmt.body, current_env)
          current_env = merge_env(current_env, body_env)

        when SyntaxTree::FunctionCallStatement
          type_check_expr(stmt.expr, current_env)

        else
          raise "Unexpected statement: #{stmt.inspect}"
        end
      end

      current_env
    end

    def merge_env(env1, env2)
      new_env = {} #: type_env

      env1.each do |name, type1|
        if type2 = env2[name]
          if type1 == type2
            new_env[name] = type1
          else
            raise "Type mismatch: #{name} is #{type1}, but #{type2} given"
          end
        end
      end

      new_env
    end

    def type_check_expr(expr, env)
      case expr
      when SyntaxTree::VarExpr
        unless env.key?(expr.name)
          diagnostics << [expr.range, "TYPE", "Undefined variable: #{expr.name}"]
        end
      when SyntaxTree::Math1Expr, SyntaxTree::Math2Expr, SyntaxTree::Math3Expr
        expr.exprs.each do |subexpr|
          next if subexpr.is_a?(String)
          type_check_expr(subexpr, env)
        end
      when SyntaxTree::LtEqExpr, SyntaxTree::LtExpr, SyntaxTree::GtEqExpr, SyntaxTree::GtExpr
        type_check_expr(expr.left, env)
        type_check_expr(expr.right, env)
      when SyntaxTree::EqualExpr, SyntaxTree::NotEqualExpr
        type_check_expr(expr.left, env)
        type_check_expr(expr.right, env)
      when SyntaxTree::FunctionCallExpr
        if (function = functions.fetch(expr.name, nil))
          unless function.params.size == expr.args.size
            diagnostics << [expr.range, "TYPE", "Arity mismatch: expected #{function.params.size} arguments, but #{expr.args.size} given"]
          end
        else
          diagnostics << [expr.range, "TYPE", "Undefined function: #{expr.name}"]
        end
        expr.args.each do |arg|
          type_check_expr(arg, env)
        end
      end

      :int
    end
  end
end
