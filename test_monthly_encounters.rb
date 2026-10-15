require 'minitest/autorun'
require 'tempfile'
require 'stringio'
require 'open3'
require 'rbconfig'
require_relative 'monthly_encounters'

class MonthlyEncountersTest < Minitest::Test
  def with_input(data)
    Tempfile.create(['fictional-encounters', '.csv']) do |file|
      file.write(data)
      file.flush
      yield file.path
    end
  end

  def report(data)
    with_input(data) do |path|
      output = StringIO.new
      MonthlyEncounters.write(path, '2019', output)
      output.string
    end
  end

  def test_monthly_counts
    data = <<~CSV
      Id,START
      alpha,2019-01-05T10:00:00Z
      beta,2019-01-20T12:00:00Z
      alpha,2019-01-05T10:00:00Z
      alpha,2019-01-05T11:00:00+01:00
      gamma,2019-03-01T00:30:00+01:00
      delta,2019-12-31T23:30:00Z
      before,2018-12-31T23:00:00Z
      after,2020-01-01T00:00:00Z
      utc-after,2019-12-31T23:30:00-01:00
      utc-inside,2020-01-01T00:30:00+01:00
    CSV
    expected = <<~CSV
      month,encounter_count
      2019-01,2
      2019-02,1
      2019-03,0
      2019-04,0
      2019-05,0
      2019-06,0
      2019-07,0
      2019-08,0
      2019-09,0
      2019-10,0
      2019-11,0
      2019-12,2
    CSV
    assert_equal expected, report(data)
  end

  def test_invalid_required_values
    [
      [",2019-01-01T00:00:00Z", 'missing Id'],
      ['   ,2019-01-01T00:00:00Z', 'missing Id'],
      ['alpha,', 'invalid START'],
      ['alpha,nonsense', 'invalid START'],
      ['alpha,2019-02-30T00:00:00Z', 'invalid START'],
      ['alpha,2019-01-01T25:00:00Z', 'invalid START'],
      ['alpha,2019-01-01T00:00:00', 'invalid START']
    ].each do |row, message|
      error = assert_raises(MonthlyEncounters::InputError) { report("Id,START\n#{row}\n") }
      assert_includes error.message, message
    end
  end

  def test_conflicting_starts_even_outside_reporting_year
    error = assert_raises(MonthlyEncounters::InputError) do
      report("Id,START\nalpha,2018-01-01T00:00:00Z\nalpha,2018-01-02T00:00:00Z\n")
    end
    assert_includes error.message, 'conflicting START'
  end

  def test_empty_year_has_twelve_zero_counts
    rows = CSV.parse(report("Id,START\n"), headers: true)
    assert_equal 12, rows.length
    assert_equal ['0'], rows.map { |row| row['encounter_count'] }.uniq
  end

  def test_missing_headers_and_invalid_year
    ['', "Id\nalpha\n", "START\n2019-01-01T00:00:00Z\n"].each do |data|
      assert_raises(MonthlyEncounters::InputError) { report(data) }
    end
    with_input("Id,START\n") do |path|
      assert_raises(MonthlyEncounters::InputError) { MonthlyEncounters.write(path, 'oops', StringIO.new) }
    end
  end

  def test_command_line_error_has_no_partial_csv
    with_input("Id,START\nalpha,2019-01-01T00:00:00Z\nbeta,invalid\n") do |path|
      stdout, stderr, status = Open3.capture3(RbConfig.ruby, File.join(__dir__, 'monthly_encounters.rb'), path, '2019')
      refute status.success?
      assert_empty stdout
      assert_includes stderr, 'Error: Record 3: invalid START'
    end
  end
end
