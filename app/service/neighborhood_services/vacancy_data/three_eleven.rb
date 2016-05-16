class NeighborhoodServices::VacancyData::ThreeEleven
  DATA_URL = 'https://data.kcmo.org/resource/7at3-sxhp.json'

  def initialize(neighborhood, three_eleven_filters = {})
    @neighborhood = neighborhood
    @vacant_filters = three_eleven_filters[:filters] || []
  end

  def data
    @data ||= query_dataset
  end

  private

  def query_dataset
    request_url = URI::escape("#{DATA_URL}?$where=neighborhood = '#{@neighborhood.name}'")
    three_eleven_data = HTTParty.get(request_url, verify: false)

    three_eleven_filtered_data(three_eleven_data)
      .values
      .select { |parcel|
        parcel["address_with_geocode"].present? && parcel["address_with_geocode"]["latitude"].present?
      }
      .map { |parcel|
        {
          "type" => "Feature",
          "geometry" => {
            "type" => "Point",
            "coordinates" => [parcel["address_with_geocode"]["longitude"].to_f, parcel["address_with_geocode"]["latitude"].to_f]
          },
          "properties" => {
            "parcel_number" => parcel['parcel_number'],
            "color" => '#ffffff',
            "disclosure_attributes" => parcel['disclosure_attributes'].uniq
          }
        }
      }
  end

  def three_eleven_filtered_data(parcel_data)
    three_eleven_filtered_data = {}

    if @vacant_filters.include?('vacant_structure')
      foreclosure_data = ::NeighborhoodServices::VacancyData::Filters::VacantStructure.new(parcel_data).filtered_data
      merge_data_set(three_eleven_filtered_data, foreclosure_data)
    end

    if @vacant_filters.include?('open')
      open_case_data = ::NeighborhoodServices::VacancyData::Filters::OpenThreeEleven.new(parcel_data).filtered_data
      merge_data_set(three_eleven_filtered_data, open_case_data)
    end

    three_eleven_filtered_data
  end

  def merge_data_set(data, data_set)
    data_set.each do |entity|
      if data[entity['parcel_id_no']]
        data[entity['parcel_id_no']]['disclosure_attributes'] += entity['disclosure_attributes']
      else
        data[entity['parcel_id_no']] = entity
      end
    end
  end
end
