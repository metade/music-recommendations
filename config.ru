require 'rubygems'
require 'rack'
require 'camping'

require 'music_recommendations.rb'
run Rack::Adapter::Camping.new( MusicRecommendations )

