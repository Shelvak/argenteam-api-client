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

  if serie.seasons.size == 1
    puts 'Solo tiene 1 temporada, descargando...'
    serie.download
  else
    puts "La serie tiene #{serie.seasons.size} temporadas, cuál bajamos?"
    puts '[0] Completa (Default)'
    serie.seasons.each_with_index do |season, i|
      if i == 5
        byebug
      end
      puts "[#{i+1}] Temporada #{i+1} (Episodios: #{season.episodes.size})"
    end
    choise = gets.chomp.to_i

    if choise == 0
      serie.download
    else
      serie.seasons[choise - 1].download
    end
  end
end
