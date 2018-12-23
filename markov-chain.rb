require 'tokenizer'
require 'json'

class SplitTokenizer
  def tokenize(line)
    line.split(' ') + ["\n"]
  end
end

class MarkovChain
  def initialize(file_name:, order:)
    @file_name = file_name
    @order = order
    @model = {}

    if File.exist? data_file
      @model = JSON.parse(File.read(data_file))
    else
      @tokens = []
      # @tokenizer = Tokenizer::WhitespaceTokenizer.new(:en)
      @tokenizer = SplitTokenizer.new
      build_tokens
      build_model
      export_model
    end
  end

  def sample
    @sample = []
    while @sample.last != "\n"
      tokens = @sample.last(@order)
      model = model_for tokens
      @sample << random_select_from(model, @sample.length.zero?)
    end
    output_sample
  end

  private

  def build_tokens
    File.readlines(input_file).each_with_index do |line, i|
      @tokens += @tokenizer.tokenize(line)
      puts "Reading line #{i + 1}"
    end
  end

  def build_model
    puts "#{@tokens.length} tokens found"
    @tokens.each_with_index do |_token, i|
      visited_children = [@model]
      child = @model
      (0..@order).each do |look_ahead|
        next if i + look_ahead >= @tokens.length
        token = @tokens[i + look_ahead]
        child[token] = {} unless child.key? token
        child = child[token]
        visited_children << child
      end
      visited_children.each do |visited_child|
        visited_child['_total_count'] = 0 unless visited_child.key? '_total_count'
        visited_child['_total_count'] += 1
      end
      puts "Processing #{i + 1} / #{@tokens.length} token"
    end
  end

  def export_model
    File.write(data_file, JSON.pretty_generate(@model))
  end

  def input_file
    "data/#{@file_name}.txt"
  end

  def data_file
    "models/#{@file_name}-order-#{@order}.json"
  end

  def model_for(tokens)
    child = @model
    tokens.each do |token|
      child = child[token]
    end
    child
  end

  def random_select_from(model, only_uppercase)
    total = model['_total_count']
    if only_uppercase
      model = model.select { |token, _| token[0] =~ /[A-Z]/ }
      total = model.count
    end
    seed = rand(0..total)
    current_count = 0
    model.each do |token, child|
      next if token == '_total_count'
      current_count += child['_total_count']
      return token if current_count >= seed
    end
  end

  def output_sample
    puts @sample.join(' ')
  end
end

chain = MarkovChain.new(file_name: ARGV[0], order: ARGV[1].to_i)
ARGV[2].to_i.times do
  chain.sample
  puts ''
end
