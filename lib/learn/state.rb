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

    def srs value, interval = nil, easiness_factor = nil
      return SpacedRepetition::Sm2.new(value) if interval.nil?
      SpacedRepetition::Sm2.new(value, interval, easiness_factor) unless interval.nil?
    end

    def mark score
      if @questions[@question_count][:interval].nil?
        sm2 = srs score
      else
        sm2 = srs(score,
                  @questions[@question_count][:interval],
                  @questions[@question_count][:easiness])
      end
      p @questions[@question_count]
      @questions[@question_count][:interval] = sm2.interval
      @questions[@question_count][:easiness] = sm2.easiness_factor
      @questions[@question_count][:repetition_date] = sm2.next_repetition_date
      @db.write_score(@questions[@question_count][:id],
                      sm2.interval,
                      sm2.easiness_factor,
                      sm2.next_repetition_date)
    end

    def shuffle
      clear
      c_puts "Shuffling!"
      @questions.shuffle!
      p @questions
      sleep 1
    end

    def state
      loop do
        if @state == :menu
          if @catagory == ''
            @state = :catagories
          else
            @question_count = 0
            menu
            case key
            when :auto then @state = :question
            when :space then @state = :question
            when :catagories then @state = :catagories
            when :shuffle then shuffle
            when :add then @state = :add
            end
          end

        elsif @state == :catagories
          select_catagory
          @state = :menu

        elsif @state == :question
          update_rehearse
          if @questions == []
            @state = :menu
          else
            clear
            show_question
            case key
            when :auto  then @state = :answer
            when :space then @state = :answer
            end
          end

        elsif @state == :answer
          update_rehearse
          c_puts
          c_puts
          show_answer
          if @rehearse
            case key
            when :auto  then @state = :is_finished
            when :space  then @state = :is_finished
            end
          else
            @state = :mark
          end

        elsif @state == :mark
          val = key
          puts "val = #{val}"
          case val
          when :score_0, :score_1, :score_2, :score_3, :score_4, :score_5
            puts 'here'
            puts "mark = #{val.to_s[6..6].to_i}"
            mark val.to_s[6..6].to_i
            
            @state = :is_finished
          end

        elsif @state == :add
          add
          @state = :menu

        elsif @state == :is_finished
          @question_count += 1
          if @question_count >= @questions.length
            @rehearse = nil
            @state = :quit
          else
            @state = :question
          end

        elsif @state == :quit
          c_puts
          c_puts 'all done'
          sleep 2
          @kb.reset
          @state = :menu
        end
      end
    end

    def key
      loop do
        event = @kb.read
        return :auto if (@rehearse && rehearse_timeout)
        case event
        when :rehearse then rehearse if @state == :menu
        when :space then return :space
        when :catagories then return :catagories
        when :shuffle then return :shuffle
        when :add then return :add
        when :quit then quit
        when :score_0 then return :score_0
        when :score_1 then return :score_1
        when :score_2 then return :score_2
        when :score_3 then return :score_3
        when :score_4 then return :score_4
        when :score_5 then return :score_5
        else
          sleep 0.01
        end
      end
    end

    def load_some_questions
      puts 'here'
      questions = YAML::load_file(QUESTIONS)
      questions.each_with_index do |x,idx|
        @db.write_question(idx, x[:qu], x[:ans])
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
        p @questions
#        exit
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


    def quit code = 0
      @db.close
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
  end
end
