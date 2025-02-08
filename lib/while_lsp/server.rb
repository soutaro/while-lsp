module WhileLSP
  class Server
    attr_reader :open_files

    def initialize()
      @open_files = {}
    end

    def start()
      lsp_loop do |method, id, params|
        STDERR.puts "Received a message from client: method=#{method.inspect}, id=#{id.inspect}, params=#{params.to_json[0, 150].inspect}"

        case method
        when "initialize"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#initialize

          id or raise
          lsp_response(id, {
            capabilities: {
              textDocumentSync: { openClose: true, change: 1 },
              completionProvider: { triggerCharacters: ["$"] },
              hoverProvider: true,
              documentSymbolProvider: true,
              definitionProvider: true,
              renameProvider: true,
              referencesProvider: true
            }
          })

        when "shutdown"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#shutdown

          id or raise
          lsp_response(id, nil)

        when "exit"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#exit
          return

        when "textDocument/didOpen"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didOpen
          uri = params[:textDocument][:uri]
          text = params[:textDocument][:text]
          open_files[uri] = program = Program.new(uri)
          program.update(text)
          if diagnostics = lsp_diagnostics(uri, program)
            lsp_notification "textDocument/publishDiagnostics", diagnostics
          end

        when "textDocument/didChange"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didChange
          uri = params[:textDocument][:uri]
          text = params[:contentChanges][0][:text]
          program = open_files[uri]
          program.update(text)
          if diagnostics = lsp_diagnostics(uri, program)
            lsp_notification "textDocument/publishDiagnostics", diagnostics
          end

        when "textDocument/didClose"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didClose
          uri = params[:textDocument][:uri]
          open_files.delete(uri)

        when "textDocument/completion"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_completion

          id or raise
          items = [] #: Array[untyped]

          %w(return function echo if while PHP_EOL <?php).each do |keyword|
            items << {
              label: keyword,
              kind: 14 # Keyword
            }
          end

          if program = open_files[params[:textDocument][:uri]]
            if program.typechecker
              program.typechecker.functions.each_value do |function|
                items << {
                  label: function.name,
                  kind: 3, # Function
                  detail: "function #{function.name}(#{function.params.join(", ")})"
                }
              end
            end
          end

          lsp_response(id, items)

        when "textDocument/hover"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_hover

          id or raise

          uri = params[:textDocument][:uri] #: String
          line = params[:position][:line] #: Integer
          character = params[:position][:character] #: Integer

          hover = nil #: untyped

          if program = open_files.fetch(uri, nil)
            pos = program.position(line, character)
            if syntax = program.locate_syntax(pos)
              STDERR.puts "Located syntax: #{syntax.inspect}"
              case syntax
              when SyntaxTree::FunctionCallExpr
                name_range = syntax.name_range
                if name_range[0] <= pos && pos <= name_range[1]
                  if typechecker = program.typechecker
                    if function = typechecker.functions[syntax.name]
                      start_line, start_char = program.line_char(name_range[0])
                      end_line, end_char = program.line_char(name_range[1])

                      hover = {
                        contents: "Function call: `#{function.name}(#{function.params.join(", ")})`",
                        range: {
                          start: { line: start_line, character: start_char },
                          end: { line: end_line, character: end_char }
                        }
                      }
                    end
                  end
                end
              end
            end
          end

          lsp_response(id, hover)

        when "textDocument/documentSymbol"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_documentSymbol

          id or raise
          lsp_response(id, nil)

        when "textDocument/definition"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_definition

          id or raise
          lsp_response(id, [])

        when "textDocument/references"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_references

          id or raise
          lsp_response(id, [])

        when "textDocument/rename"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_rename

          id or raise
          lsp_response(id, nil)
        end
      end
    end

    def lsp_diagnostics(uri, program)
      if diagnostics = program.diagnostics
        {
          uri: uri,
          diagnostics: diagnostics.map do |range, code, message|
            start_line, start_char = program.line_char(range[0])
            end_line, end_char = program.line_char(range[1])

            {
              range: {
                start: { line: start_line, character: start_char },
                end: { line: end_line, character: end_char },
              },
              severity: 1, # 1: Error, 2: Warning, 3: Information, 4: Hint
              code: code,
              source: "WhileLSP",
              message: message,
            }
          end
        }
      end
    end

    def lsp_loop()
      while line = STDIN.gets
        line.chomp!
        case
        when line =~ /^Content-Type: .+$/
          # Ignore content type
        when line =~ /^Content-Length: (\d+)$/
          STDIN.gets
          content = STDIN.read($1.to_i) or raise
          json = JSON.parse(content, symbolize_names: true)
          yield json[:method], json[:id], json[:params]
        else
          raise "Unexpected line: #{line.inspect}"
        end
      end
    end

    def lsp_response(id, result)
      message = { id: id, result: result, jsonrpc: "2.0" }
      json = message.to_json

      STDERR.puts "Sending a response to client: id=#{id.inspect}, result=#{result.to_json[0, 150].inspect}"
      STDOUT.write("Content-Length: #{json.bytesize}\r\n\r\n#{json}")
      STDOUT.flush
    end

    def lsp_notification(method, params)
      message = { method: method, params: params, jsonrpc: "2.0" }
      json = message.to_json

      STDERR.puts "Sending a notification to client: method=#{method.inspect}, params=#{params.to_json[0, 150].inspect}"
      STDOUT.write("Content-Length: #{json.bytesize}\r\n\r\n#{json}")
      STDOUT.flush
    end
  end
end
