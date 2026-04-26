# Reusable frame-based animation player
# Records frames, then lets you navigate with arrow keys
#
# Usage:
#   require_relative 'animation_player'
#   player = AnimationPlayer.new
#   player.add_frame("Title") { |out| out << "  5 █████\n  3 ███\n" }
#   player.play

require 'io/console'

class AnimationPlayer
  def initialize
    @frames = []
  end

  def add_frame(label = "", &block)
    output = ""
    block.call(output) if block
    @frames << { label: label, content: output }
  end

  def play
    idx = 0
    render(idx)

    loop do
      key = read_key
      case key
      when :right, " "
        idx = [idx + 1, @frames.length - 1].min
      when :left
        idx = [idx - 1, 0].max
      when :home
        idx = 0
      when :end_key
        idx = @frames.length - 1
      when :quit
        puts "\e[0m"
        break
      end
      render(idx)
    end
  end

  private

  def render(idx)
    system("clear") || system("cls")
    frame = @frames[idx]
    puts frame[:label]
    puts
    print frame[:content]
    puts
    puts "  \e[90m[#{idx + 1}/#{@frames.length}] ← → navigate | Home/End jump | q quit\e[0m"
  end

  def read_key
    char = $stdin.getch
    case char
    when "\e"
      seq = $stdin.read_nonblock(2) rescue ""
      case seq
      when "[D" then :left
      when "[C" then :right
      when "[H" then :home
      when "[F" then :end_key
      else :unknown
      end
    when "q", "\u0003"  # q or Ctrl-C
      :quit
    when " "
      " "
    else
      :unknown
    end
  end
end

# Helper: draw bar chart into a string
def render_bars(arr, highlight: [], colors: {})
  out = ""
  arr.each_with_index do |val, i|
    bar = "█" * (val * 3)
    color = if colors[i]
              colors[i]
            elsif highlight.include?(i)
              "\e[32m"  # green
            else
              "\e[37m"  # white
            end
    out << "#{color}  #{val.to_s.rjust(2)} #{bar}\e[0m\n"
  end
  out
end
