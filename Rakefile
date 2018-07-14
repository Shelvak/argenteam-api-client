require 'byebug'
require 'rake'
require 'bundler/setup'

require 'transmission'

task default: [:run]

task :run do
  $GEM_ROOT = Dir.pwd
  require File.expand_path('../lib/argenteam-api-client', __FILE__)

  puts 'Qué serie vamos a bajar?'
  name = gets.chomp
  serie = Serie.search(name)

  unless serie
    puts 'No se encontró una mierda'
    exit 0
  end

  return 'Sin transmission no hay joda...' unless Torrent.healthcheck

  if serie.seasons.size == 1
    puts 'Solo tiene 1 temporada, descargando...'
    serie.download
    exit 0
  end

  puts "La serie tiene #{serie.seasons.size} temporadas, cuál bajamos?"
  puts '(Multiples separadas por coma)'
  puts '[0] Completa (Default)'
  serie.seasons.each_with_index do |season, i|
    n = i+1
    puts "[#{n}] Temporada #{n} (Episodios: #{season.episodes.size})"
  end
  choises = gets.chomp.to_s.split(',').map(&:to_i).sort

  if choises.include?(0)
    serie.download
    exit 0
  end

  choises.each { |i| serie.seasons[i-1].download }
end
