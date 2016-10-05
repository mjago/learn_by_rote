require 'colorize'
require 'fileutils'
require 'yaml'

module ModLearn
  class State

    ROOT            = File.expand_path '~/'
    HERE            = File.dirname(__FILE__)
    LEARN_DIR       = '.learn'
    CONFIG_NAME     = 'config.yml'
    QUESTIONS_NAME  = 'questions.yml'
    LEARN           = File.join ROOT, LEARN_DIR
    VERSION         = File.join HERE, '..','..','VERSION'
    DEFAULT_CONFIG  = File.join HERE, '..','..',CONFIG_NAME
    CONFIG          = File.join LEARN,CONFIG_NAME
    QUESTIONS_DIR   = File.join LEARN,'questions'
    QUESTIONS       = File.join QUESTIONS_DIR,QUESTIONS_NAME

    def initialize
      @kb = Keyboard.new
      @config = {}
      setup
      do_config
      @state = :start
      @version = '0.0.1'
      @question_count = 0
      load_questions
      state
    end

    def setup
      @start_time = Time.now
      learn = LEARN
      qu_dir = QUESTIONS_DIR
      qu = QUESTIONS
      Dir.mkdir learn unless Dir.exist? learn
      c_puts 'qu_dir ' + qu_dir
      c_puts 'qu ' + qu
      Dir.mkdir qu_dir unless Dir.exist? qu_dir
      FileUtils.touch QUESTIONS
    end

    def load_config
      create_config unless File.exist? CONFIG
      @config = YAML::load_file(CONFIG)
      do_configs
    end

    def save_config
      File.open(CONFIG, 'w') { |f| f.write @config.to_yaml}
    end

    def do_config
      @config = {}
      @config[:colour] = true
      @text_colour = :red
    end

    def now
      Time.now
    end

    def rehearse_timeout
      if now > @rehearse_timeout
        update_rehearse
      end
    end

    def wait arg
      loop do
        if arg == :key
          event = @kb.read
          if @rehearse
            return if rehearse_timeout
          end
          if event == :rehearse
            rehearse
          elsif event == :shuffle
            clear
            c_puts "Shuffling!"
            @questions.shuffle!
            sleep 2
            clear
            menu
          elsif event == :add
            add
          elsif event == :quit
            quit
          elsif event != :no_event
            return
          else
            sleep 0.01
          end
        end
      end
    end

    def update_rehearse
      @rehearse_timeout = now + @rehearse
    end

    def rehearse interval = 5
      @rehearse, @rehearse_timeout = interval, now
    end

    def load_questions
      create_questions unless File.exist? QUESTIONS
      @questions = YAML::load_file(QUESTIONS)
      puts @questions
#      exit
#      do_configs
    end

    def save_questions
      File.open(QUESTIONS, 'w') { |f| f.write @questions.to_yaml}
    end

    def add
      @kb.stop
      @kb = nil
      loop do
        clear
        c_puts "Enter Question"
        qu = $stdin.gets
        if qu.strip == ''
          p @questions
          save_questions
          break
        else
          c_puts "Enter Answer"
          ans = $stdin.gets
          @questions << {qu: qu.strip, ans: ans.strip}
        end
      end
      c_puts
      @kb = Keyboard.new
      puts 'here'
    end

    def state
      loop do
        if @state == :start
          @question_count = 0
          menu
          @state = :question unless wait(:key)

        elsif @state == :question
          clear
          show_question
          @state = :answer unless wait(:key)

        elsif @state == :answer
          c_puts
          c_puts
          show_answer
          @state = :is_finished unless wait(:key)

        elsif @state == :is_finished
          @question_count += 1
          if @question_count >= @questions.length
            @state = :quit
          else
            @state = :question
          end

        elsif @state == :quit
          c_puts
          c_puts 'all done'
          sleep 2
          @state = :start
        end
      end
    end

    def load_menu_maybe
      if ARGV[0] == '-h' || ARGV[0] == '--menu' || ARGV[0] == '-?'
        menu
        quit
      end
    end

    def clear
      system 'clear' or system 'cls'
    end


    def quit code = 0
      system("stty -raw echo")
      exit code
    end

    def c_print x, col = @text_colour
      STDOUT.print x.colorize col if @config[:colour]
      STDOUT.print x          unless @config[:colour]
    end

    def c_puts x = '', col = @text_colour
      c_print x, col
      c_print "\n\r"
    end

    def show_question
      c_puts @questions[@question_count][:qu]
    end

    def show_answer
      c_puts @questions[@question_count][:ans]
    end

    def menu
      unless @menu
        clear
        c_puts " Learn by Rote (#{@version})"
        c_puts
        c_puts " Rehearse      - R  ",    @system_colour
        c_puts " Add Qu's      - A ",     @system_colour
        c_puts " Shuffle Qu's  - S ",     @system_colour
        c_puts " Start         - Return", @system_colour
        c_puts " Start         - Spacebar", @system_colour
        c_puts
        c_puts " Quit          - Q  ",    @system_colour
      else
        redraw
        @menu = nil
      end
    end
  end
end
