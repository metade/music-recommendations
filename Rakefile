require 'pp'
require 'yaml'

task :prune_space do
  space = 'data/brands_artists/brands_artists.txt'
  pruned_space = 'data/brands_artists/brands_artists_pruned.txt'
  out = File.open(pruned_space, 'w')
  File.open(space) do |f|
    f.each_line do |line| 
      matches = line.scan(/([\w|-]+) (\d), /) 
      total = matches.inject(0) { |sum, m| sum += m.last.to_i }
      average = (total/matches.size.to_f)
      out.puts line if average > 1
    end
  end
  out.close
end

task :build_pruned_space => :prune_space do
  path = 'data/brands_artists/brands_artists_pruned'
  system('ssmake', "#{path}.llss", "#{path}.txt")
end