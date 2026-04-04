require 'csv'

class LazyCSV
  def initialize(path)
    @path = path
  end

  def select_columns(*columns)
    @select_columns = columns
    self
  end

  def filter(&block)
    @filter_block = block
    self
  end

  def each(&block)
    csv = CSV.open(@path, headers: true)
    csv.each do |row|
      next unless @filter_block.call(row)
      result = {}

      @select_columns.each do |column|
        result[column] = row.field(column)
      end
      block.call(result)
    end
  end
end

LazyCSV.new("data.csv")
  .select_columns("name", "salary")
  .filter { |row| row["salary"].to_i > 65000 }
  .each { |row| puts row }
# => {"name"=>"Alice", "salary"=>"80000"}
# => {"name"=>"Carol", "salary"=>"90000"}
# => {"name"=>"Dave", "salary"=>"70000"}
