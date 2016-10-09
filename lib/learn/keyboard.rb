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
      @mode = :normal
      @event = :no_event
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
        when "c",'C'
          @event = :catagories
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
        when ' '
          @event = :space
        when '?', 'h'
          @event = :help
        when '0'
          @event = :_0
        when '1'
          @event = :_1
        when '2'
          @event = :_2
        when '3'
          @event = :_3
        when '4'
          @event = :_4
        when '5'
          @event = :_5
        else
          @event = :no_event
        end
        ke_events
      end
    end
  end
end
