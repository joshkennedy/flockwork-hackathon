module Planner
  # Reads the Planner's JSON object while it streams. Only complete values are exposed: the card once its
  # object closes, and each added item once its object closes. Nothing here persists; the final parse does.
  class PartialResponse
    WHITESPACE = " \n\r\t".freeze

    attr_reader :card, :added

    def initialize
      @text = +""
      @card = nil
      @added = []
    end

    def <<(text)
      @text << text
      scan
      self
    end

    private
      def scan
        @card = nil
        @added = []
        pos = skip(1, "," + WHITESPACE)
        while pos && @text[pos] != "}"
          key, pos = string_at(pos)
          break unless key && (pos = skip(pos, WHITESPACE)) && @text[pos] == ":"

          pos = skip(pos + 1, WHITESPACE)
          break unless pos

          if key == "added" && @text[pos] == "["
            pos = scan_added(pos + 1)
            break unless pos
          else
            value_end = value_end(pos)
            break unless value_end

            @card = parse_hash(pos, value_end) if key == "card"
            pos = value_end
          end
          pos = skip(pos, "," + WHITESPACE)
        end
      end

      def scan_added(pos)
        loop do
          pos = skip(pos, "," + WHITESPACE)
          return nil unless pos
          return pos + 1 if @text[pos] == "]"
          return nil unless @text[pos] == "{"

          finish = balanced_end(pos)
          return nil unless finish

          item = parse_hash(pos, finish)
          @added << item if item
          pos = finish
        end
      end

      # Returns the index after the next non-skipped character, or nil when the buffer ends first.
      def skip(pos, chars)
        pos += 1 while pos < @text.length && chars.include?(@text[pos])
        pos if pos < @text.length
      end

      def string_at(pos)
        finish = value_end(pos)
        return unless finish && @text[pos] == '"'

        [ JSON.parse(@text[pos...finish]), finish ]
      end

      def value_end(pos)
        case @text[pos]
        when '"' then string_end(pos)
        when "{", "[" then balanced_end(pos)
        else
          # A scalar is complete only once a delimiter follows it, so a partial number is never read.
          finish = pos
          finish += 1 while finish < @text.length && !(",}] \n\r\t".include?(@text[finish]))
          finish if finish < @text.length
        end
      end

      def string_end(pos)
        index = pos + 1
        while index < @text.length
          case @text[index]
          when "\\" then index += 2
          when '"' then return index + 1
          else index += 1
          end
        end
        nil
      end

      def balanced_end(pos)
        depth = 0
        index = pos
        while index < @text.length
          char = @text[index]
          if char == '"'
            index = string_end(index) or return nil
            next
          elsif char == "{" || char == "["
            depth += 1
          elsif char == "}" || char == "]"
            depth -= 1
            return index + 1 if depth.zero?
          end
          index += 1
        end
        nil
      end

      def parse_hash(from, to)
        value = JSON.parse(@text[from...to])
        value if value.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end
  end
end
