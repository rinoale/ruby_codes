class StringCalculator
  def initialize(num)
    @num = num
    @result = num
  end

  def method_missing(args)
    op, r_opnd = args.to_s.split('_')

    @result = case op
             when 'add'
               @result + r_opnd.to_i
             when 'subtract'
               @result - r_opnd.to_i
             when 'multiply'
               @result * r_opnd.to_i
             when 'divide'
               raise ZeroDivisionError if r_opnd.to_i.zero?

               @result / r_opnd.to_i
             end

    self
  end

  def respond_to_missing?(*args)
    puts "result: #{@result}"
    @result = @num
    false
  end
end

calc = StringCalculator.new(10)

pp calc.add_5           # => 15
pp calc.subtract_3      # => 7 (from original 10)
pp calc.add_5.subtract_3.multiply_2  # => 24  ((10 + 5 - 3) * 2)
pp calc.divide_0        # => "Error: Division by zero"
