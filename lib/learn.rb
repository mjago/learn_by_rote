require          'spaced_repetition'
require          'sqlite3'
require_relative 'learn/state.rb'
require_relative 'learn/keyboard.rb'
require_relative 'learn/questions.rb'
require_relative 'learn/database.rb'

ModLearn::State.new
