class LazySql
  include Enumerable

  attr_reader :klass, :sql

  def initialize(klass:, sql:)
    @klass, @sql = klass.to_s, sql
  end

  def to_sql
    sql
  end

  def each(&block)
    records.each(&block)
  end

  private

  def records
    @records ||= klass.constantize.find_by_sql(sql)
  end
end
