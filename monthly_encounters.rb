require 'csv'
require 'date'

module MonthlyEncounters
  class InputError < StandardError; end

  # Require a complete timestamp with an explicit timezone, never the machine's timezone.
  TIMESTAMP = /\A\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d+)?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)\z/

  def self.write(path, year, output)
    raise InputError, 'Reporting year must be four digits, from 0001 to 9999' unless /\A\d{4}\z/.match?(year) && year.to_i.positive?

    starts = {}
    counts = Array.new(12, 0)
    CSV.open(path, headers: true) do |csv|
      first = csv.shift
      unless csv.headers.is_a?(Array) && %w[Id START].all? { |name| csv.headers.include?(name) }
        raise InputError, 'CSV must contain Id and START columns'
      end
      [first].compact.chain(csv.each).each.with_index(2) do |row, line|
        id = row['Id']
        raise InputError, "Record #{line}: missing Id" if id.nil? || id.strip.empty?

        value = row['START']
        begin
          raise ArgumentError unless value && TIMESTAMP.match?(value)
          start = DateTime.iso8601(value).new_offset(0)
        rescue ArgumentError
          raise InputError, "Record #{line}: invalid START #{value.inspect}; expected an ISO 8601 timestamp with timezone"
        end

        if starts.key?(id)
          raise InputError, "Record #{line}: conflicting START timestamps for Id #{id.inspect}" unless starts[id] == start
          next
        end
        starts[id] = start
        counts[start.month - 1] += 1 if start.year == year.to_i
      end
    end

    # Write only after validation succeeds, avoiding a partial report on input errors.
    csv = CSV.new(output)
    csv << %w[month encounter_count]
    counts.each_with_index { |count, index| csv << [format('%04d-%02d', year.to_i, index + 1), count] }
  end
end

if $PROGRAM_NAME == __FILE__
  begin
    raise MonthlyEncounters::InputError, 'Usage: ruby monthly_encounters.rb INPUT.csv YEAR' unless ARGV.length == 2
    MonthlyEncounters.write(ARGV[0], ARGV[1], $stdout)
  rescue MonthlyEncounters::InputError, CSV::MalformedCSVError, SystemCallError => e
    warn "Error: #{e.message}"
    exit 1
  end
end
