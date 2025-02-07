module WhileLSP
  class Server
    def initialize()
      @files = {}
    end

    def start()
      lsp_loop do |method, id, params|
        STDERR.puts "Received a message from client: method=#{method.inspect}, id=#{id.inspect}, params=#{params.to_json[0, 100].inspect}"
        case method
        when "initialize"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#initialize

          id or raise
          lsp_response(id, {
            capabilities: {
              textDocumentSync: { openClose: true, change: 1 },
              completionProvider: { triggerCharacters: ["$"] },
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
          @files[uri] = program = Program.new(uri)
          program.update(text)
          if diagnostics = lsp_diagnostics(uri, program)
            lsp_notification "textDocument/publishDiagnostics", diagnostics
          end
        when "textDocument/didChange"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didChange
          uri = params[:textDocument][:uri]
          text = params[:contentChanges][0][:text]
          program = @files[uri]
          program.update(text)
          if diagnostics = lsp_diagnostics(uri, program)
            lsp_notification "textDocument/publishDiagnostics", diagnostics
          end
        when "textDocument/didClose"
          # https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didClose
          uri = params[:textDocument][:uri]
          @files.delete(uri)
        when "textDocument/completion"
          id or raise
          items = [] #: Array[untyped]

          %w(return function echo if while PHP_EOL <?php).each do |keyword|
            items << {
              label: keyword,
              kind: 14 # Keyword
            }
          end

          if program = @files[params[:textDocument][:uri]]
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
        end
      end
    end

    def lsp_diagnostics(uri, program)
      if diagnostics = program.diagnostics
        {
          uri: uri,
          diagnostics: diagnostics.map do |range, code, message|
            start_line, start_char = program.line_char(range.begin)
            end_line, end_char = program.line_char(range.end)

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

      STDERR.puts "Sending a response to client: id=#{id.inspect}, result=#{result.to_json[0, 100].inspect}"
      STDOUT.write("Content-Length: #{json.bytesize}\r\n\r\n#{json}")
      STDOUT.flush
    end

    def lsp_notification(method, params)
      message = { method: method, params: params, jsonrpc: "2.0" }
      json = message.to_json

      STDERR.puts "Sending a notification to client: method=#{method.inspect}, params=#{params.to_json[0, 100].inspect}"
      STDOUT.write("Content-Length: #{json.bytesize}\r\n\r\n#{json}")
      STDOUT.flush
    end
  end
end
