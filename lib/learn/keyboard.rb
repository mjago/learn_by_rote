require 'io/console'

module ModLearn
  class Keyboard

    def initialize
      @mode = :normal
      @event = :no_event
      @key = Thread.new do
        run
      end
    end

    def stop
      @key.kill.join
    end

    def reset
      STDIN.flush
    end

    def ke_events
      sleep 0.001
    end

    def read
      ret_val = @event
      reset
      @event = :no_event
      ret_val
    end

    def run
      loop do
        str = ''
        loop do
          str = STDIN.getch
          if str == "\e"
            @mode = :escape
          else
            case @mode
            when :escape
              if str == "["
                @mode = :escape_2
              else
                @mode = :normal
              end
            when :escape_2
              @event =  :previous     if str == "A"
              @event =  :next         if str == "B"
              @event = :page_forward  if str == "C"
              @event = :previous      if str == "D"
              @mode = :normal

            else
              break if @event == :no_event
            end
          end
          ke_events
        end

        case str
        when "\e"
          @mode = :escape
        when "a",'A'
          @event = :add
        when ' '
          @event = :page_forward
        when "q",'Q', "\u0003", "\u0004"
          @event = :quit
        when 'p', 'P'
          @event = :pause
        when 'f', 'F'
          @event = :forward
        when 'r', 'R'
          @event = :rehearse
        when 's', 'S'
          @event = :shuffle
        when 'x', 'X', "\r"
          @event = :play
        when 'i', 'I'
          @event = :info
        when '?', 'h'
          @event = :help
        else
          @event = :no_event
        end
        ke_events
      end
    end
  end
end
