require 'colorize'
require 'fileutils'
require 'yaml'
require 'word_wrap'
require 'word_wrap/core_ext'

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
      @sm2 = SpacedRepetition::Sm2
      @config = {}
      setup
      do_config
      @state = :menu
      @version = '0.0.1'
      @question_count = 0
      @db = Database.new
      @questions = @db.read_questions
      @catagories = @db.read_catagories
      @catagory = ''
      load_some_questions if @questions == []
      state
    end

    def key
      loop do
        event = @kb.read
        return :auto if (@rehearse && rehearse_timeout)
        case event
        when :rehearse then rehearse if @state == :menu
        when :quit then quit
        when :no_event then do_events
        else
          return event
        end
      end
    end

    def state
      loop do
        self.send @state.to_s + '_state'
        do_events
      end
    end

    def menu_state
      if @catagory == ''
        @state = :catagories
      else
        @question_count = 0
        menu
        case key
        when :auto       then @state = :question
        when :start      then @state = :question
        when :catagories then @state = :catagories
        when :shuffle    then shuffle
        when :add        then @state = :add
        end
      end
    end

    def catagories_state
      select_catagory
      @state = :menu
    end

    def question_state
      update_rehearse
      if questions_exhausted?
        @state = :is_finished
      elsif @questions == []
        @state = :menu
      else
        clear
        if (@rehearse || check_question_due)
          show_question
          case key
          when :auto  then @state = :answer
          when :_0, :_1, :_2, :_3, :_4, :_5 then @state = :answer
          when :space then @state = :answer
          end
        end
      end
    end

    def answer_state
      update_rehearse
      c_puts
      c_puts
      if questions_exhausted?
        @state = :is_finished
      else
        show_answer
        if @rehearse
          case key
          when :auto  then @state = :is_finished
          when :space  then @state = :is_finished
          end
        else
          @state = :mark
        end
      end
    end

    def mark_state
      val = key
      case val
      when :_0, :_1, :_2, :_3, :_4, :_5
        mark val.to_s[1..1].to_i
        @state = :is_finished
      end
    end

    def add_state
      add
      @state = :menu
    end

    def is_finished_state
      @question_count += 1
      if @question_count >= @questions.length
        @rehearse = nil
        @state = :end_session
      else
        @state = :question
      end
    end

    def end_session_state
      c_puts
      c_puts 'All Done!'
      do_events 2
      @kb.reset
      @state = :menu
    end

    def srs value, interval = nil, easiness_factor = nil
      return SpacedRepetition::Sm2.new(value) if interval.nil?
      SpacedRepetition::Sm2.new(value, interval, easiness_factor) unless interval.nil?
    end

    def questions_exhausted?
      @question_count >= @questions.length
    end

    def check_question_due
      return false if questions_exhausted?
      return true if @questions[@question_count][:next_date].nil?
      loop do
        due_date = Date.strptime(@questions[@question_count][:next_date], "%Y-%m-%d")
        if due_date <= Date.today
          return true
        else
          @question_count += 1
          if questions_exhausted?
            break
          end
        end
      end
      return false
    end

    def mark score
      if @questions[@question_count][:interval].nil?
        sm2 = srs score
      else
        sm2 = srs(score,
                  @questions[@question_count][:interval],
                  @questions[@question_count][:easiness])
      end
      @questions[@question_count][:interval] = sm2.interval
      @questions[@question_count][:easiness] = (sm2.easiness_factor * 100).round / 100.0
      @questions[@question_count][:next_date] = sm2.next_repetition_date.to_s
      @db.write_score(@questions[@question_count][:id],
                      @questions[@question_count][:interval],
                      @questions[@question_count][:easiness],
                      @questions[@question_count][:next_date])
    end

    def shuffle
      clear
      c_puts "Shuffling!"
      @questions.shuffle!
      do_events 1
    end

    def load_some_questions
      questions = YAML::load_file(QUESTIONS)
      questions.each_with_index do |x,idx|
        @db.write_question(1, x[:qu], x[:ans])
      end
    end

    def setup
      @start_time = Time.now
      learn = LEARN
      qu_dir = QUESTIONS_DIR
      Dir.mkdir learn unless Dir.exist? learn
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
      @text_colour = :blue
      @text_width = 40
    end

    def now
      Time.now
    end

    def rehearse_timeout
      if now > @rehearse_timeout
        update_rehearse
      end
    end

    def update_rehearse
      if @rehearse
        @rehearse_timeout = now + @rehearse
      end
    end

    def rehearse interval = 3
      @rehearse, @rehearse_timeout = interval, now
      @question_count = 0
    end

    def save_questions questions
      questions.each do |qu|
        @db.write_question(@catagory, qu[:qu], qu[:ans])
      end
    end

    def list_catagories
      clear
      @catagories.each do |cat|
        c_puts (cat[:id]).to_s + ') ' + cat[:catagory]
      end
    end

    def get_catagory_by_id id
      @catagories.each do |cat|
        if cat[:id] == id
          return cat[:catagory]
        end
      end
      ''
    end

    def select_catagory
      @kb.stop
      list_catagories
      loop do
        c_puts
        c_puts "Enter Catagory"
        qu = $stdin.gets
        id = qu.strip.to_i
        @catagory = id
        @questions = @db.read_questions(@catagory)
        c_puts get_catagory_by_id(id)
        break
      end
      @kb = Keyboard.new
    end

    def add
      new_questions = []
      @kb.stop
      loop do
        clear
        c_puts "Enter Question"
        qu = $stdin.gets
        if qu.strip == ''
          save_questions new_questions
          break
        else
          c_puts "Enter Answer"
          ans = $stdin.gets
          new_questions << {qu: qu.strip, ans: ans.strip}
        end
      end
      c_puts
      @kb = Keyboard.new
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

    def c_print x, col = @text_colour
      STDOUT.print x.colorize col if @config[:colour]
      STDOUT.print x          unless @config[:colour]
    end

    def c_puts x = '', col = @text_colour
      c_print x, col
      c_print "\n\r"
    end

    def c_wrap x = '', col = @text_colour
      wrap = x.wrap(@text_width).split("\n")
      wrap.each do |wr|
        c_print wr, col
        c_print "\n\r"
      end
    end

    def show_question
      c_wrap @questions[@question_count][:qu] unless @questions == []
    end

    def show_answer
      c_wrap @questions[@question_count][:ans] unless @questions == []
    end

    def menu
      unless @menu
        clear
        c_puts " Learn by Rote (#{@version})"
        c_puts
        c_print " Catagory - "
        c_print  get_catagory_by_id(@catagory) unless @catagory == ''
        c_puts
        c_puts
        c_puts " Rehearse      - R ",     @system_colour
        c_puts " Add Qu's      - A ",     @system_colour
        c_puts " Categories    - C ",     @system_colour
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

    def do_events wait = 0.005
      sleep wait
    end

    def quit code = 0
      @db.close
      system("stty -raw echo")
      exit code
    end
  end
end
