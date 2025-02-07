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
  end
end
