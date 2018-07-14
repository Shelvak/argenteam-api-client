# Ruby stlib
require 'json'
require 'net/http'
require 'ostruct'
require 'yaml'
# Vendor
require 'transmission'

class Base

  $lib_path = File.expand_path('afip_service', 'lib')

  def self.site
    'http://argenteam.net/api/v1/'
  end

  def self.query(q)
    requestaso(site + "search?q=#{q.strip}&type=#{self.name}").results
  end

  def self.find(id)
    new(requestaso(site + "#{name}?id=#{id}"))
  end

  def self.fetch(id)
    requestaso(site + "#{name}?id=#{id}")
  end

  def self.requestaso(url)
    uri = URI(url)
    response = Net::HTTP.get(uri)

    recursive_ostruct(JSON.parse(response))
  end

  def self.recursive_ostruct(hash)
    OpenStruct.new(hash.each_with_object({}) do |(key, val), memo|
      memo[key] = if val.is_a?(Hash)
                    recursive_ostruct(val)
                  elsif val.is_a?(Array)
                    val.map {|v| recursive_ostruct(v) }
                  else
                    val
                  end
    end)
  end
end

class Season
  attr_accessor :season, :episodes

  def initialize(attrs)
    @season = attrs.season
    @episodes = attrs.episodes.map { |e| e.season = attrs.season; Episode.new(e) }
    @episodes_with_720 = []
  end

  def download
    episodes.each(&:parse_torrents)

    find_720_torrent || find_pija_quality_torrent
  end

  def find_720_torrent
    episodes.each do |e|
      if e.find_720_torrent
        puts "Encontrado #{e.to_s}"
        @episodes_with_720 << e.id
      end
    end

    episodes.size == @episodes_with_720.size
  end

  def find_pija_quality_torrent

    episodes.each do |e|
      unless @episodes_with_720.include?(e.id)
        puts "Buscando pija_quality_torrents para #{e.to_s}"
        e.find_pija_quality_torrent
      end
    end
  end
end

class Serie < Base
  @@_checked_series = {}

  attr_accessor :id, :title, :seasons

  def initialize(attrs)
    @id = attrs.id
    @title = attrs.title
    if attrs.seasons.is_a?(Array)
      @seasons = attrs.seasons.map {|s| Season.new(s) }
    end
  end

  def self.name
    'tvshow'
  end

  def self.search(q)
    r = query(q)

    r.each { |s| @@_checked_series[s.title] = s }
    serie = case r.size
              when 0 then nil
              when 1 then r.first
              else
                show_series(r)
            end
    return unless serie
    new(find(serie.id))
  end

  def self.show_series(results, recall=false)
    puts 'No seas boludo, elegí en serio' if recall
    puts 'Encontrados multiples resultados. Seleccioná 1'
    results.each_with_index do |s, i|
      puts "(#{i.to_s.rjust(3, ' ')})  #{s.title} (Año: #{s.year}, Temporadas: #{s.seasons})#{ '[Default]' if i == 0 }"
    end

    picked = gets
    results[picked.strip.to_i] || show_series(results, true)
  end

  def episodes
    seasons.map(&:episodes).flatten
  end

  def download
    seasons.map(&:download)
  end
end

class Episode < Base
  attr_accessor :id, :number, :season, :title, :releases

  def initialize(attrs)
    @id = attrs.id.to_i
    @number = attrs.number
    @season = attrs.season.to_i
    @title = attrs.title
    @releases = attrs.releases
    @torrents_with_720_and_subs = []
    @torrents_with_subs = []
    @torrents_with_720 = []
    @torrents = []
  end

  def to_s
    "[#{season.to_s.rjust(2, '0')}x#{number.to_s.rjust(2, '0')}] #{title}"
  end

  def fetch
    puts "Fetching #{to_s}"
    self.releases = self.class.fetch(id).releases
  end

  def parse_torrents
    return if releases
    fetch
    releases.map do |r|
      next unless r.torrents.first
      subs = r.subtitles.size > 0
      _720 = r.tags.match(/720/)
      case
        when subs && _720
          @torrents_with_720_and_subs << r
        when _720
          @torrents_with_720 << r
        when subs
          @torrents_with_subs << r
        else
          @torrents << r
      end
    end
  end

  def find_pija_quality_torrent
    r = case
          when @torrents_with_subs.size > 0
            choose_between_releases(@torrents_with_subs)
          when @torrents.size > 0
            choose_between_releases(@torrents)
        end

    r ? add_torrent_from_release(r) : (puts "No hay torrents para #{to_s}")
  end

  def find_720_torrent
    r = case
          when @torrents_with_720_and_subs.size > 0
            choose_between_releases(@torrents_with_720_and_subs)
          when @torrents_with_720.size > 0
            choose_between_releases(@torrents_with_720)
        end

    r ? add_torrent_from_release(r) : (puts "No hay torrents 720 para #{to_s}")
  end

  def choose_between_releases(releases)
    return releases.first if releases.size == 1

    sorted = releases.sort_by do |r|
      size, measure = r.size.to_s.split(' ')  # size: '123 MB'
      size *= 1000 if measure == 'GB'
      size
    end

    puts 'Cual bajamos?:'
    sorted.each_with_index do |r, i|
      puts "(#{i.to_s.rjust(3, ' ')}) #{r.source}-#{r.codec} #{r.tags} (#{r.size}) [Team: #{r.team}] [Subs: #{r.subtitles.size}] #{ '[Default]' if i == 0 }"
    end
    picked = gets
    sorted[picked.to_i] || sorted.first
  end

  def add_torrent_from_release(release)
    t = release.torrents.first
    if t
      puts "Agregando #{to_s} torrent"
      Torrent.add(t.alt || t.uri)  # ensure always we add the magnet
    end
  end
end

class Torrent
  @@_client = nil
  def self.add(link)
    init_client unless @@_client

    # client.add doesn't return true for duplicated
    response = client.send(:rpc, 'torrent-add', {'filename' => link})
    response['result'] == 'success'
  end

  def self.client
    @@_client
  end

  def self.init_client
    config = YAML.load(File.read($GEM_ROOT + '/config.yml'))
    config[:host] = config['host'] || '127.0.0.1'
    config[:port] = config['port'] || 9091
    config[:user] = config['user'] || 'admin'
    config[:pass] = config['pass'] || 'admin'

    @@_client = Transmission.new(config)
  end
end
