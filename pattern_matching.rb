hash = {
  pay_method: 'bank',
  status: 'ready'
}

case hash
in {a: a, d:}
  puts a
in { pay_method: pay_method, status: status } if %w[bank paypal alipay].include?(pay_method) && status == 'ready'
  puts "#{pay_method} is #{status}"
else
  puts 'no matching'
end
