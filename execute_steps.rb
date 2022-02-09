class Step
  def execute_step
    raise NotImplementedError, "#{self.class} has not implemented method '#{__method__}'"
  end

  def name
    self.class.to_s
  end
end

class AbstractStep < Step
  attr_accessor :next_step

  def stay_step
  end
end

class IdPassword < AbstractStep
  def execute_step(args)
    args[:id] == 'gbsong01' && args[:password] == '1234'
  end
end

class Otp < AbstractStep
  def execute_step(args)
    args[:otp] == '123'
  end
end

class ThirdStep < AbstractStep
  def execute_step
    true
  end
end

class ForthStep < AbstractStep
  def execute_step
    true
  end
end

class FifthStep < AbstractStep
  def execute_step
    true
  end
end

$current_step_name = nil
class LoginProcess
  @@login_processes = []
  @@steps = %w[id_password otp third_step forth_step fifth_step]

  # @@previous_step = nil
  # @@steps.each do |step|
  #   step_obj = step.split('_').(&:capitalize).join.constantize.new
  #   @@previous_step.next_step = step_obj if @@previous_step
  #   @@login_processes << step_obj
  #   @@previous_step = step_obj
  # end

  attr_accessor :on_complete

  def initialize
    $current_step_name = @@steps.first
  end

  def execute(**args)
    return finish_step unless current_step

    puts "===#{current_step.name} executing==="
    if current_step.execute_step **args
      puts "===#{current_step.name} success==="
      $current_step_name = next_step_name
    else
      puts "===#{current_step.name} fail==="
      # raise StepFailError.new "Step failed on #{current_step.name}"
    end
  end

  def current_step
    return unless $current_step_name

    Object.const_get($current_step_name.split('_').collect(&:capitalize).join).new
  end

  def next_step_name
    @@steps[@@steps.index($current_step_name) + 1]
  end

  private

  def finish_step
    $current_step_name = nil
    on_complete.call
  end

  class StepFailError < StandardError
  end
end

login_process = LoginProcess.new
login_process.on_complete = proc { puts 'all steps done' }

login_process.execute id: 'gbsong01', password: '1234'
puts login_process.current_step.name
puts login_process.next_step_name
login_process.execute otp: '123'

login_process.execute
login_process.execute
login_process.execute
login_process.execute
login_process.execute
login_process.execute
