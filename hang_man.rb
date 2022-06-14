# frozen_string_literal: false

require 'json'

### LOAD AND SAVE SECTION

# load words to be guessed
def extract_words
  file = File.new('words.txt', 'r')
  words = []
  until file.eof?
    word = file.readline
    words.push(word.gsub("\n", '')) if choice_in_range?(word.length, 13, 6)
  end
  file.close
  words
end

# load existing file, start new game if none exist
def load_game
  if Dir.exist?('saved_games') && !Dir.empty?('saved_games')
    load_file
  else
    puts 'There are no saved games, a new game has been started '
    Game.new(nil, nil, nil, nil)
  end
end

# load data into new Game class
def load_file
  file = options(Dir.children('./saved_games'), 'Select a file to load')
  puts 'Resuming from previous session'
  Game.json_create(JSON.parse(File.read("./saved_games/#{file}")))
end

# save game onto user's drive
def save_game(data)
  Dir.mkdir('saved_games') unless Dir.exist?('saved_games')
  prompt('Choose a file name')
  file_name = prompt_file_name
  write_to_file(file_name, data)
end

# create file that will be used to save data
def write_to_file(file_name, data)
  file_name = overwrite(file_name)
  File.open("./saved_games/#{file_name}.json", 'w') do |file|
    File.truncate(file, 0)
    file.puts data
    puts "\"#{file_name}\" has been saved"
  end
end

# check if file exists
def file_exists?(file_name)
  Dir.children('./saved_games').any? do |saved_files|
    saved_files.gsub('.json', '').eql?(file_name)
  end
end

# if user chooses file that exists while saving, ask if they want to overwrite
def overwrite(file_name)
  return file_name unless file_exists?(file_name)

  new_file = file_name
  unless options(['Yes', "Create new file named as '#{file_name}[#{Dir.children('./saved_games').length}]'"],
                 'This file already exists, want to overwrite it?').eql?('Yes')
    new_file += "[#{Dir.children('./saved_games').length}]"
  end
  new_file
end

# user enters delimitted file name
def prompt_file_name
  gets.chomp.gsub(' ', '_')
end

### OPTIONS SECTION

# show user available options
def display_options(option_list)
  formatted_options = ''
  option_list.each_with_index { |option, idx| formatted_options += "#{idx + 1}: #{option}   " }
  formatted_options
end

# prompt user with a list of options
def prompt_option(option_list, prompt)
  print "\n#{prompt} ("
  option_list.each_with_index do |option, idx|
    print option
    unless (option_list.length - 1).eql?(idx)
      print option_list.length.eql?(idx + 2) ? ' or ' : ', '
    end
  end
  puts ')'
end

# prompt user
def prompt(message)
  puts message
  print "\n>> "
end

# select list of options
def options(option_list, prompt = 'Please choose one of the following options')
  prompt_option(option_list, prompt)
  puts "\nSelect a number corresponding to an option:"
  prompt(display_options(option_list))
  option_list[validate_option(option_list).to_i - 1]
end

# user selects corret value for options
def validate_option(option_list)
  choice = gets.chomp until condition?(choice, option_list)
  puts ''
  choice
end

# condition
def condition?(choice, option_list)
  return true if choice_is_number?(choice) && choice_in_range?(choice.to_i, option_list.length)

  error_message(choice_is_number?(choice) ? 'out of range' : 'must input number') unless choice.nil?
end

# is choice in range?
def choice_in_range?(choice, max_range, min_range = 1)
  return if choice.nil?

  (choice >= min_range) && (choice <= max_range)
end

# is choice a number?
def choice_is_number?(choice)
  return if choice.nil?

  choice.scan(/\d+/).length.eql?(choice.length)
end

# prompt user with error
def error_message(context)
  prompt("Error, #{context}, please try again") if context
end

## Helper methods

# timer
def count_down(message, custom_interval = 3, unique_char = nil)
  i = custom_interval
  print "#{message} -> "
  until i.zero?
    print unique_char || i
    sleep(1)
    i -= 1
  end
  puts ''
end

# is player human or computer?
def get_setter(player)
  player.eql?('Human') ? Human.new : Computer.new
end

# did the guesser find the correct letter?
def letter_found?(guessed_letter, correct_letter)
  correct_letter['correct_letter'].eql?(guessed_letter) && correct_letter['found'].eql?(false)
end

# prompt for save name
def save_name
  prompt('Please enter a name for this save')
end

### CLASSES

# Game
class Game
  attr_reader :board, :setter, :guesser, :guessed_word

  def initialize(setter, guesser, board, guessed_word)
    @setter = setter
    @guesser = guesser
    @board = board
    @guessed_word = guessed_word
    init_players if setter.nil?
    @board.put_board(@guesser.wrong_tries, @guesser.chosen_letters, @guessed_word) unless @guesser.wrong_tries.zero?
  end

  # convert data into json
  def to_json(*keys)
    {
      JSON.create_id => self.class.name,
      data: {
        setter: @setter.data,
        guesser: @guesser.data,
        board: @board.data,
        guessed_word: @guessed_word
      }
    }.to_json(*keys)
  end

  # extract data from json
  def self.json_create(data)
    setter = get_setter(data['data']['setter']['player_type'])
    guesser = Human.new('guesser')
    board = Board.new(data['data']['board']['columns'])
    setter.load_data(data['data']['setter'])
    guesser.load_data(data['data']['guesser'])
    guessed_word = data['data']['guessed_word']
    new(setter, guesser, board, guessed_word)
  end

  # play
  def play_game
    init_columns if @guesser.wrong_tries.eql?(0)
    until @guesser.wrong_tries.eql?(7) || @guessed_word.none?(&:nil?)
      return 'quit' if evaluate_guessed_letter.eql?('quit')
    end
    evaluate_winner(@guesser.wrong_tries)
    @guesser.wrong_tries = 0
    @guesser.chosen_letters = []
  end

  private

  # set players
  def init_players
    player = options(%w[Human Computer], 'What should be the setter?')
    create_players(player)
    @setter.player_name
    @guesser.player_name
  end

  # create board
  def init_board(columns)
    @board = Board.new(columns)
    @board.put_board(6, [])
  end

  # create players
  def create_players(player)
    @setter = get_setter(player)
    @guesser = Human.new('guesser')
  end

  # set columns (how many letters)
  def init_columns
    @setter.setup_word
    puts 'This is what the board looks like when the whole character is present'
    init_board(@setter.word.length)
    @guessed_word = Array.new(@setter.word.length)
  end

  # calculate letter that user chose
  def evaluate_guessed_letter
    letter = enter_letter
    return letter if letter.eql?('quit')

    @guesser.chosen_letters.push(letter) unless letter.eql?('save')
    unless @setter.word.find { |correct_letter| letter_found?(letter, correct_letter) }
      letter = @guesser.guess_was_wrong
    end
    add_correct_letter(letter)
    @board.put_board(@guesser.wrong_tries, @guesser.chosen_letters, @guessed_word)
  end

  # user enters letter
  def enter_letter
    letter = @guesser.guess_letter(@board, @guessed_word)
    while letter.eql?('save')
      save_game(to_json)
      @board.put_board(@guesser.wrong_tries, @guesser.chosen_letters, @guessed_word)
      letter = @guesser.guess_letter(@board, @guessed_word)
    end
    letter
  end

  # check if a player won
  def evaluate_winner(wrong_tries)
    wrong_tries.eql?(7) ? @setter.winner(@setter.word) : @guesser.winner(@setter.word)
    @board.show_results(@setter, @guesser)
  end

  # add correct letter to board
  def add_correct_letter(guessed_letter)
    return if guessed_letter.nil?

    @setter.word.each_with_index do |correct_letter, idx|
      if letter_found?(guessed_letter, correct_letter)
        @guessed_word[idx] = guessed_letter
        @setter.found_letter(idx)
      end
    end
  end
end

# Player
class Player
  attr_reader :score, :word, :name
  attr_accessor :wrong_tries, :chosen_letters

  def initialize(player_type, player_mode, name = '', score = 0, wrong_tries = 0)
    @player_type = player_type
    @player_mode = player_mode
    @score = score
    @chosen_letters = []
    @wrong_tries = wrong_tries
    @name = name
  end

  # convert data into json
  def data
    {
      player_name: @name,
      player_type: @player_type,
      player_mode: @player_mode,
      score: @score,
      wrong_tries: @wrong_tries,
      correct_word: @word,
      chosen_letters: @chosen_letters
    }
  end

  # extract data from json
  def load_data(data)
    @name = data['player_name']
    @score = data['score']
    @wrong_tries = data['wrong_tries']
    @word = data['correct_word']
    @chosen_letters = data['chosen_letters']
  end

  # set correct word
  def setup_word(word)
    @word = word.split('').each_with_object([]) do |letter, arr|
      arr.push({ 'correct_letter' => letter, 'found' => false })
    end
  end

  # letter is found
  def found_letter(idx)
    @word[idx]['found'] = true
  end

  # set player name
  def player_name(name)
    @name = name.capitalize
    puts "\nWelcome to hangman #{@name}, you will be #{@player_mode}"
    puts ''
  end

  # guesser guessed wrong
  def guess_was_wrong
    @wrong_tries += 1
    nil
  end

  # player won
  def winner(word_arr)
    puts "End of game, word was #{joined_word(word_arr)}"
    print "Congrats #{@name}#{', the guesser could not find the word.' if @player_mode.eql?('setter')}"
    puts ' You win and you gained a point'
    @score += 1
  end

  # convert individual letters into one string
  def joined_word(word_arr)
    word_arr.reduce('') do |str, letter|
      str += letter['correct_letter']
      str
    end
  end
end

# Human
class Human < Player
  def initialize(player_mode = 'setter')
    super('Human', player_mode)
  end

  # set human name
  def player_name
    prompt("Human (#{@player_mode}), please enter your name")
    super(gets.chomp)
  end

  # human guesses letter
  def guess_letter(board, guessed_word)
    prompt_guesser
    letter = nil
    validate_guess(letter, board, guessed_word)
  end

  # human sets up word
  def setup_word
    @wrong_tries = 0
    prompt("#{@name.capitalize} (setter), please enter the secret word (between 5 and 12 characters)")
    word = ''
    until choice_in_range?(word.length, 12, 5)
      word = gets.chomp
      error_message('word must be between 5 and 12 characters inclusive') unless choice_in_range?(word.length, 12, 5)
    end
    super(word)
  end

  private

  # check if guess was a valid value
  def validate_guess(letter, board, guessed_word)
    until letter && choice_in_range?(letter.length, 1)
      letter = gets.chomp
      if letter.downcase.eql?('quit') || letter.downcase.eql?('save')
        are_you_sure?(letter, board, guessed_word) ? break : next
      end
      validation_error(letter)
    end
    letter.downcase
  end

  # prompt error if guesser types wrong value
  def validation_error(letter)
    return if letter.nil? || choice_in_range?(letter.length, 1)

    error_message('only one letter, "save" or "quit" is accepted')
  end

  # is guesser sure?
  def are_you_sure?(context, board, guessed_word)
    return 'Yes' if options(%w[Yes No], "Are you sure you want to #{context}?").eql?('Yes')

    board.put_board(@wrong_tries, @chosen_letters, guessed_word)
    prompt_guesser
  end
end

def prompt_guesser
  prompt("#{@name}, Choose a (1) character to guess the code, type 'save' to save current game and type 'quit' to exit")
end

# Computer
class Computer < Player
  def initialize(player_mode = 'setter')
    super('Computer', player_mode)
  end

  # computer generates name
  def player_name
    count_down('Computer choosing name')
    super("Computer_#{rand(0..999)}")
  end

  # computer generates word
  def setup_word
    count_down("#{@name} setting up word")
    words = extract_words
    super(words[rand(0...words.length)])
  end
end

# Board
class Board
  attr_reader :columns

  def initialize(columns)
    @columns = columns
    @hang_man_limbs = ["F O\n", 'F/', '|', "\\\n", 'F/', ' \\']
  end

  # convert data into hash
  def data
    {
      columns: @columns
    }
  end

  # display board
  def put_board(limbs, chosen_letters, guessed_word = nil)
    print positioning('__')
    puts '_'
    print positioning('  ')
    puts ' \\'
    puts hang_man_guy(limbs.eql?(7) ? 6 : limbs)
    puts "\n\nSo far, you chose >> #{chosen_letters.join(' ')}" unless chosen_letters.empty?
    puts "\nCorrect Letters:"
    lines(guessed_word)
  end

  # display results
  def show_results(setter, guesser)
    puts "\nPoints:"
    puts "#{guesser.name} (guesser): #{guesser.score} "
    puts "#{setter.name} (setter): #{setter.score} "
  end

  private

  # build hang man guy
  def hang_man_guy(limbs)
    guy = positioning('  ')
    guy += "( )\n"
    add_limbs(guy, limbs)
  end

  # add limbs to hang man guy
  def add_limbs(guy, limbs)
    limbs.times do |limb|
      guy += if @hang_man_limbs[limb].include?('F')
               positioning('  ') + @hang_man_limbs[limb].sub('F', '')
             else
               @hang_man_limbs[limb]
             end
    end
    guy
  end

  # print word onto lines
  def lines(word)
    puts ''
    word&.each { |letter| print " #{letter || ' '}   " }
    puts ''
    print positioning('---  ')
    puts ''
  end

  # position board based on how many lines there are
  def positioning(character)
    str = ''
    @columns.times { str += character }
    str
  end
end

### OPERATIONS

puts 'Welcome to mastermind, in order to play,'
puts 'Player must choose a letter that has been'
puts 'Pre selected by the computer or human as the setter'
puts 'can choose whether a computer or human sets'
puts 'the correct word. Human can set whatever they'
puts 'want (must be between 5 and 12 characters inclusive)'
puts 'but the computer will randomly choose their word.'
puts 'The word guesser must find all the letters until after'
puts 'the stick-man figure fully appears (or 7 tries). If the guesser'
puts 'wins, they earn a point, whereas the setter gains a '
puts 'point if the guesser loses. There are no rounds, points (for each game)'
puts 'go on forever unless the guesser (always human)'
puts 'overwrites a save. There is no character validation for the guesser,'
puts 'but they must only type one character per round. The user can'
puts 'save the game onto their drive while they are guessing. They'
puts 'will also be prompted to save if they quit the game.'
puts "\n                    Let's begin"

game = options(['new game', 'load existing game']).eql?('new game') ? Game.new(nil, nil, nil, nil) : load_game

play_again = 'Yes'

while game && play_again.eql?('Yes')
  break if game.play_game.eql?('quit')

  play_again = options(%w[Yes No], 'Want to play again?')
end

save_game(game.to_json) if options(%w[Yes No], 'Save current game?').eql?('Yes')

puts "\nGoodbye!!!"
