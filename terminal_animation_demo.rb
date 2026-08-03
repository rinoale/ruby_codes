#!/usr/bin/env ruby
# frozen_string_literal: true

module TerminalAnimation
  ESC = "\e"

  # Flush every print immediately — without this, bytes sit in Ruby's internal
  # buffer and escape sequences never reach the terminal until the buffer fills.
  $stdout.sync = true

  module_function

  def demo_carriage_return
    puts <<~HEADER
      Recipe 1: Carriage Return — single-line overwrite

    HEADER
    %w[Compiling Linking Optimizing Packaging Done!].each_with_index do |step, i|
      pct = ((i + 1) * 20)
      print "\r#{ESC}[K[#{pct}%] #{step}..."

      sleep 0.6
    end
    puts "\r#{ESC}[K[100%] Complete!"
  end

  def demo_cursor_up
    puts <<~HEADER
      Recipe 2: Cursor Up + Erase — multi-line overwrite

    HEADER
    n = 3
    10.times do |tick|
      print "#{ESC}[#{n}A" unless tick.zero?
      n.times do |row|
        val = (tick * 10 + row * 5) % 100
        filled = val / 5
        bar = "#" * filled + "." * (20 - filled)
        puts "#{ESC}[K  Task #{row + 1}: [#{bar}] #{val}%"
      end

      sleep 0.3
    end
  end

  def demo_full_clear
    frame1 = <<~'ART'
          *
         /|\
        / | \
       /  |  \
      /___+___\
    ART
    frame2 = <<~'ART'
          *
         /|\
        / | \
       /  |  \
      /___+___\
         |||
    ART
    frame3 = <<~'ART'
          *
         /|\
        / | \
       /  |  \
      /___+___\
         |||
      ===++===
    ART

    frames = [frame1, frame2, frame3]
    print "#{ESC}[?25l"

    begin
      8.times do
        frames.each do |frame|
          print "#{ESC}[H#{ESC}[2J"
          puts <<~HEADER
            Recipe 3: Full Screen Clear — frame animation

          HEADER
          print frame
          sleep 0.4
        end
      end
    ensure
      print "#{ESC}[?25h"
    end
  end

  def demo_scroll_region
    rows = `tput lines`.to_i
    content_end = rows - 2

    print "#{ESC}[?25l#{ESC}[2J#{ESC}[H"
    print "#{ESC}[1;#{content_end}r"

    begin
      verbs = %w[compiling linking testing deploying bundling]
      15.times do |i|
        pct = ((i + 1) * 100 / 15)
        filled = pct * 30 / 100
        bar = "█" * filled + "░" * (30 - filled)
        label = "Item #{i + 1}: #{verbs.sample} #{('a'..'z').to_a.sample(8).join}"

        print "#{ESC}[#{content_end};1H"
        puts label

        print "#{ESC}[#{rows};1H#{ESC}[K"
        print "#{ESC}[7m [#{bar}] #{pct}% — #{i + 1}/15 #{ESC}[0m"

  
        sleep 0.3
      end
      sleep 1
    ensure
      print "#{ESC}[r#{ESC}[?25h#{ESC}[#{rows};1H\n"
    end
  end

  def demo_alt_screen
    print "#{ESC}[?1049h#{ESC}[?25l"

    begin
      spinner = %w[| / - \\]
      5.times do |tick|
        print "#{ESC}[H#{ESC}[2J"
        puts "Recipe 5: Alternate Screen Buffer"
        puts "Your previous terminal content is preserved."
        puts
        puts "Tick: #{tick + 1}/5"
        puts "Spinner: #{spinner[tick % 4]}"

        sleep 0.8
      end
    ensure
      print "#{ESC}[?25h#{ESC}[?1049l"
    end
    puts "Back to normal screen. Nothing was lost."
  end

  def demo_progress_bar
    puts <<~HEADER
      Recipe 6: Progress Bar

    HEADER
    cols = `tput cols`.to_i
    total = 50

    total.times do |i|
      pct = ((i + 1) * 100 / total)
      label = " #{pct}% "
      bar_w = [cols - label.length - 4, 10].max
      filled = (i + 1) * bar_w / total
      bar = "█" * filled + "░" * (bar_w - filled)
      print "\r#{ESC}[K[#{bar}]#{label}"

      sleep 0.05
    end
    puts
  end

  def demo_fixed_bottom
    rows = `tput lines`.to_i
    print "#{ESC}[?25l"

    begin
      12.times do |i|
        pct = ((i + 1) * 100 / 12)

        puts (i + 1) * 111

        print "#{ESC}[s"
        print "#{ESC}[#{rows};1H#{ESC}[K"
        print "#{ESC}[7m #{pct}% fixed output #{ESC}[0m"
        print "#{ESC}[u"

  
        sleep 0.4
      end
      sleep 1
    ensure
      print "#{ESC}[?25h#{ESC}[#{rows};1H\n"
    end
  end

  DEMOS = {
    "1" => [:demo_carriage_return,  "Carriage return — single-line overwrite"],
    "2" => [:demo_cursor_up,       "Cursor up — multi-line in-place update"],
    "3" => [:demo_full_clear,      "Full screen clear — frame animation"],
    "4" => [:demo_scroll_region,   "Scroll region — fixed status bar at bottom"],
    "5" => [:demo_alt_screen,      "Alternate screen buffer"],
    "6" => [:demo_progress_bar,    "Progress bar with width calc"],
    "7" => [:demo_fixed_bottom,    "Fixed bottom — save/restore cursor"],
  }.freeze

  def self.run(choice)
    if choice && DEMOS.key?(choice)
      send(DEMOS[choice][0])
    else
      puts "Terminal Animation Recipes"
      puts "=" * 40
      DEMOS.each { |k, (_, desc)| puts "  #{k}) #{desc}" }
      puts
      puts "Usage: ruby #{$0} [1-7]"
    end
  end
end

TerminalAnimation.run(ARGV[0])
