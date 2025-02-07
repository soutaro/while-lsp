module WhileLSP
  class Parser
    attr_reader :src, :scanner, :current_token

    Token = Data.define(:type, :value, :position)

    class Token
      def range
        (position - value.size)...position
      end

      def self.build(type, scanner)
        new(type, scanner.matched || raise, scanner.charpos)
      end
    end

    class Error < StandardError
      attr_reader :range

      def initialize(range, message)
        super(message)
        @range = range
      end
    end

    def initialize(src)
      @src = src.dup
      @scanner = StringScanner.new(@src)
    end

    def current_token!
      current_token or raise "#current_token is nil"
    end

    def current_token?(*types)
      types.any? {|t| current_token!.type == t }
    end

    def advance_token
      if scanner.eos?
        @current_token = Token.new(:kEOF, "", scanner.charpos)
        return current_token
      end

      case
      when scanner.scan(/\s+/)
        advance_token()
      when scanner.scan(/\/\/.*/)
        advance_token()
      when scanner.scan(/<\?php/)
        advance_token()
      when scanner.scan(/function/)
        @current_token = Token.build(:kFUNCTION, scanner)
      when scanner.scan(/\{/)
        @current_token = Token.build(:kLBRACE, scanner)
      when scanner.scan(/\}/)
        @current_token = Token.build(:kRBRACE, scanner)
      when scanner.scan(/\(/)
        @current_token = Token.build(:kLPAREN, scanner)
      when scanner.scan(/\)/)
        @current_token = Token.build(:kRPAREN, scanner)
      when scanner.scan(/return\b/)
        @current_token = Token.build(:kRETURN, scanner)
      when scanner.scan(/while\b/)
        @current_token = Token.build(:kWHILE, scanner)
      when scanner.scan(/if\b/)
        @current_token = Token.build(:kIF, scanner)
      when scanner.scan(/else\b/)
        @current_token = Token.build(:kELSE, scanner)
      when scanner.scan(/echo\b/)
        @current_token = Token.build(:kECHO, scanner)
      when scanner.scan(/PHP_EOL\b/)
        @current_token = Token.build(:kPHPEOL, scanner)
      when scanner.scan(/;/)
        @current_token = Token.build(:kSEMICOLON, scanner)
      when scanner.scan(/\$[a-z]\w*/)
        @current_token = Token.build(:kVARNAME, scanner)
      when scanner.scan(/[A-Z]\w*/)
        @current_token = Token.build(:kFUNCNAME, scanner)
      when scanner.scan(/,/)
        @current_token = Token.build(:kCOMMA, scanner)
      when scanner.scan(/==/)
        @current_token = Token.build(:kEQ, scanner)
      when scanner.scan(/!=/)
        @current_token = Token.build(:kNEQ, scanner)
      when scanner.scan(/>=/)
        @current_token = Token.build(:kGTEQ, scanner)
      when scanner.scan(/>/)
        @current_token = Token.build(:kGT, scanner)
      when scanner.scan(/<=/)
        @current_token = Token.build(:kLTEQ, scanner)
      when scanner.scan(/</)
        @current_token = Token.build(:kLT, scanner)
      when scanner.scan(/=/)
        @current_token = Token.build(:kEQ, scanner)
      when scanner.scan(/\+/)
        @current_token = Token.build(:kPLUS, scanner)
      when scanner.scan(/\-/)
        @current_token = Token.build(:kMINUS, scanner)
      when scanner.scan(/\*/)
        @current_token = Token.build(:kMUL, scanner)
      when scanner.scan(/\//)
        @current_token = Token.build(:kDIV, scanner)
      when scanner.scan(/%/)
        @current_token = Token.build(:kMOD, scanner)
      when scanner.scan(/\d+/)
        @current_token = Token.build(:kINT, scanner)
      else
        raise Error.new(scanner.charpos...src.size, "Unexpected token: #{scanner.rest}")
      end
      current_token
    end

    def consume(type)
      unless current_token?(type)
        raise Error.new(current_token!.range, "Expected token: #{type}, but got: #{current_token.inspect}")
      end
      tok = current_token!
      advance_token()
      tok
    end

    def parse()
      advance_token()
      parse_program()
    end

    def parse_program()
      program = [] #: SyntaxTree::program

      loop do
        case current_token!.type
        when :kEOF
          return program
        when :kFUNCTION
          program << parse_function_decl()
        when :kECHO, :kVARNAME, :kWHILE, :kIF
          program << parse_statement()
        else
          raise Error.new(current_token!.range, "Unexpected token: #{current_token.inspect}")
        end
      end
    end

    def parse_function_decl()
      start_token = consume(:kFUNCTION)
      name = consume(:kFUNCNAME).value
      consume(:kLPAREN)
      params = [] #: Array[String]
      while true
        params << consume(:kVARNAME).value
        if (current_token!.type == :kRPAREN)
          break
        end
        consume(:kCOMMA)
      end
      consume(:kRPAREN)
      consume(:kLBRACE)
      body = [] #: Array[SyntaxTree::statement]
      begin
        body << parse_statement()
      end until current_token?(:kRBRACE)
      close_token = consume(:kRBRACE)
      SyntaxTree::FunctionDeclaration.new(name, params, body, concat_range(start_token.range, close_token.range))
    end

    def parse_statement()
      case
      when echo_token = consume_token?(:kECHO)
        exprs = [] #: Array[SyntaxTree::expr]

        while true
          exprs << parse_expr()
          if current_token?(:kSEMICOLON)
            break
          end
          consume(:kCOMMA)
        end

        consume(:kSEMICOLON)
        SyntaxTree::EchoStatement.new(exprs, concat_range(echo_token.range, exprs[-1].range))

      when return_token = consume_token?(:kRETURN)
        expr = parse_expr()
        consume(:kSEMICOLON)
        SyntaxTree::ReturnStatement.new(expr, concat_range(return_token.range, expr.range))

      when name_token = consume_token?(:kVARNAME)
        name = name_token.value
        consume(:kEQ)
        expr = parse_expr()
        consume(:kSEMICOLON)
        SyntaxTree::AssignStatement.new(name, expr, concat_range(name_token.range, expr.range))

      when if_token = consume_token?(:kIF)
        then_body = [] #: Array[SyntaxTree::statement]
        else_body = [] #: Array[SyntaxTree::statement]

        consume(:kLPAREN)
        condition = parse_expr()
        consume(:kRPAREN)

        consume(:kLBRACE)
        begin
          then_body << parse_statement()
        end until current_token?(:kRBRACE)
        close_token = consume(:kRBRACE)

        if consume_token?(:kELSE)
          consume(:kLBRACE)
          begin
            else_body << parse_statement()
          end until current_token?(:kRBRACE)
          close_token = consume(:kRBRACE)
        end

        SyntaxTree::IfStatement.new(condition, then_body, else_body, concat_range(if_token.range, close_token.range))
      when while_token = consume_token?(:kWHILE)
        body = [] #: Array[SyntaxTree::statement]

        consume(:kLPAREN)
        condition = parse_expr()
        consume(:kRPAREN)

        consume(:kLBRACE)
        begin
          body << parse_statement()
        end until current_token?(:kRBRACE)
        close_token = consume(:kRBRACE)

        SyntaxTree::WhileStatement.new(condition, body, concat_range(while_token.range, close_token.range))
      else
        raise Error.new(current_token!.range, "Unexpected token for statement: #{current_token!.inspect}")
      end
    end

    def parse_expr()
      expr = parse_expr4

      case
      when consume_token?(:kEQ)
        lhs = parse_expr4
        SyntaxTree::EqualExpr.new(expr, lhs, concat_range(expr.range, lhs.range))
      when consume_token?(:kNEQ)
        lhs = parse_expr4
        SyntaxTree::NotEqualExpr.new(expr, lhs, concat_range(expr.range, lhs.range))
      else
        expr
      end
    end

    # <, >, <=, >=
    def parse_expr4()
      expr = parse_expr3

      case
      when consume_token?(:kLT)
        lhs = parse_expr3
        SyntaxTree::LtExpr.new(expr, lhs, concat_range(expr.range, lhs.range))
      when consume_token?(:kLTEQ)
        lhs = parse_expr3
        SyntaxTree::LtEqExpr.new(expr, lhs, concat_range(expr.range, lhs.range))
      when consume_token?(:kGT)
        lhs = parse_expr3
        SyntaxTree::GtExpr.new(expr, lhs, concat_range(expr.range, lhs.range))
      when consume_token?(:kGTEQ)
        lhs = parse_expr3
        SyntaxTree::GtEqExpr.new(expr, lhs, concat_range(expr.range, lhs.range))
      else
        expr
      end
    end

    # +, -
    def parse_expr3
      first_expr = parse_expr2()
      last_expr = first_expr

      exprs = [] #: Array[SyntaxTree::Math3Expr::operator | SyntaxTree::expr]
      exprs << first_expr

      while operator_token = consume_token?(:kPLUS, :kMINUS)
        operator = operator_token.value #: "+" | "-"
        exprs << operator

        last_expr = parse_expr2
        exprs << last_expr
      end

      if exprs.size == 1
        first_expr
      else
        SyntaxTree::Math3Expr.new(exprs, concat_range(first_expr.range, last_expr.range))
      end
    end

    # %
    def parse_expr2
      first_expr = parse_expr1()
      last_expr = first_expr

      exprs = [] #: Array[SyntaxTree::Math2Expr::operator | SyntaxTree::expr]
      exprs << first_expr

      while operator_token = consume_token?(:kMOD)
        operator = operator_token.value #: "%"
        exprs << operator
        last_expr = parse_expr1()
        exprs << last_expr
      end

      if exprs.size == 1
        first_expr
      else
        SyntaxTree::Math2Expr.new(exprs, concat_range(first_expr.range, last_expr.range))
      end
    end

    # *, /
    def parse_expr1()
      first_expr = parse_expr0()
      last_expr = first_expr

      exprs = [] #: Array[SyntaxTree::Math1Expr::operator | SyntaxTree::expr]
      exprs << first_expr

      while operator_token = consume_token?(:kMUL, :kDIV)
        operator = operator_token.value #: "*" | "/"
        exprs << operator

        last_expr = parse_expr0()
        exprs << last_expr
      end

      if exprs.size == 1
        first_expr
      else
        SyntaxTree::Math1Expr.new(exprs, concat_range(first_expr.range, last_expr.range))
      end
    end

    def consume_token?(*types)
      if current_token?(*types)
        tok = current_token
        advance_token
        tok
      end
    end

    def concat_range(range1, range2)
      if range1.is_a?(Range)
        if range2.is_a?(Range)
          range1.begin...range2.end
        else
          range1.begin...range2
        end
      else
        if range2.is_a?(Range)
          range1...range2.end
        else
          range1...range2
        end
      end
    end

    def parse_expr0
      case
      when tok = consume_token?(:kVARNAME)
        SyntaxTree::VarExpr.new(tok.value, tok.range)
      when tok = consume_token?(:kINT)
        SyntaxTree::IntExpr.new(Integer(tok.value), tok.range)
      when tok = consume_token?(:kPHPEOL)
        SyntaxTree::PHPEOLExpr.new(tok.range)
      when tok = consume_token?(:kLPAREN)
        expr = parse_expr()
        consume(:kRPAREN)
        expr
      when tok = consume_token?(:kFUNCNAME)
        name = tok.value
        args = [] #: Array[SyntaxTree::expr]

        consume(:kLPAREN)
        while true
          args << parse_expr()
          if current_token?(:kRPAREN)
            break
          end
          consume(:kCOMMA)
        end
        end_tok = consume(:kRPAREN)

        SyntaxTree::FunctionCallExpr.new(name, args, concat_range(tok.range, end_tok.range))
      else
        raise Error.new(current_token!.range, "Unexpected token for expr: #{current_token!.inspect}")
      end
    end
  end
end
