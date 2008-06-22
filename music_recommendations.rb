require 'rubygems'
require 'yaml'
require 'json'
require 'camping'
require 'mime/types'

require 'pp'

require 'lib/semantic_space_recommender'
require 'lib/last_fm_profile'

include SemanticSpace

class ArtistRecommendation
  def name
    @name ||= MusicRecommendations.artists[self.gid] or self.gid
  end
  def <=>(other)
    self.name <=> other.name
  end
  def to_hash
    { :gid => gid, :name => name, :score => score }
  end
end

class BrandRecommendation
  def title
    @title ||= MusicRecommendations.brands[self.pid] or self.pid
  end
  def <=>(other)
    self.title <=> other.title
  end
  def to_hash
    { :pid => pid, :title => title, :score => score }
  end
end

Camping.goes :MusicRecommendations
module MusicRecommendations

  def self.config
    @@config ||= YAML.load_file('config/semantic_space.yml')
  end

  def self.artists
    @@artists ||= YAML.load_file(config[:artists]) or {}
  end

  def self.brands
    @@brands = YAML.load_file(config[:brands]) or {}
  end

  def self.recommender
    @@recommender ||= SemanticSpaceRecommender.new(config[:space], config[:k])
  end
  
  def accept(format=nil)
    if (format and format =~ /.js(on)?/)
      'application/json'
    else
      env.ACCEPT.nil? ? (env.HTTP_ACCEPT.nil? ? 'text/html' : env.HTTP_ACCEPT) : env.ACCEPT
    end
  end
  
  # redefine render to fix issue in passenger
  def render(method)
    my_layout { self.send(method) }
  end
  
end

module MusicRecommendations::Controllers
  class Index < R '/'
    def get
      render :index
    end
  end
  
  class Artists < R '/artists'
    def get
      @artists = MusicRecommendations::recommender.artists
      render :artists
    end
  end

  class Artist < R '/artists/([\w\d-]{36})(.*?)'
    def get(mbid, format=nil)
      @artist = ArtistRecommendation.new(mbid)
      @recommended_artists = MusicRecommendations::recommender.artist_artists(mbid)
      @recommended_brands = MusicRecommendations::recommender.artist_brands(mbid)

      case accept(format)
        when %r{application/json}
          @headers['Content-Type'] = 'application/json'
          { :artist => @artist.to_hash,
            :recommended_artists => @recommended_artists.map { |r| r.to_hash },
            :recommended_brands => @recommended_brands.map { |r| r.to_hash }, 
          }.to_json
        else render :artist
      end
    end
  end
  
  class Brands < R '/brands'
    def get
      @brands = MusicRecommendations::recommender.brands.sort
      render :brands
    end
  end

  class Brand < R '/brands/([\w\d]{8})(.*)'
    def get(brand, format=nil)
      @brand = BrandRecommendation.new(brand)
      @recommended_brands = MusicRecommendations::recommender.brand_brands(brand)
      @recommended_artists = MusicRecommendations::recommender.brand_artists(brand)

      case accept(format)
        when %r{application/json}
          @headers['Content-Type'] = 'application/json'
          { :brand => @brand.to_hash,
            :recommended_artists => @recommended_artists.map { |r| r.to_hash },
            :recommended_brands => @recommended_brands.map { |r| r.to_hash }, 
          }.to_json
        else render :brand
      end
    end
  end

  class MyRecommendations < R '/recommend/lastfm/(.*)'
    def get(profile)
      if profile.blank?
        if input[:profile].blank?
          redirect R(Index)
        else
          redirect R(MyRecommendations, input[:profile])  
        end
      else      
        @profile = profile
        top_artists = LastFmProfile.new(@profile).top_artists
        @recommended_brands = MusicRecommendations::recommender.query_brands(top_artists)
        @recommended_artists = MusicRecommendations::recommender.query_artists(top_artists)
        render :my_recommendations
      end
    end
  end
end

module MusicRecommendations::Views

  def my_layout
    html do
      body do
        div.container! do
          self << yield
        end
      end
    end
  end
  
  def index
    div.header! do
      h1 'Semantic Space'
      p { 'A recommendation engine based on Semantic Spaces for music.' } 
      p { 'Browse by ' } 
      ul do
        li { a 'Artists', :href => R(Artists) }
        li { a 'Brands', :href => R(Brands) }
      end
      p { text 'Suggest some artists/brands based on my '; a 'Last.fm', :href => 'http://last.fm'; text ' profile:' }
      form :method => :get, :action => '/recommend/lastfm/' do
        input :name => 'profile', :type => 'text'
        input :type => :submit
      end
    end
  end
  
  def artists
    div.header! do
      h1 'Artists'
    end
    _navigation      
    p 'A selection of artists:'
    ol do 
      for artist in @artists
        li { a artist.name, :href=>R(Artist, artist.gid, nil) }
      end
    end
  end
  
  def brands
    div.header! do
      h1 'List of Brands'
    end
    _navigation 
    ol do 
      for brand in @brands
        li { a brand.title, :href=>R(Brand, brand.pid, nil) }
      end
    end
  end

  def artist
    div.header! do
      h1 'Artist: ' + @artist.name
    end
    _navigation
    _link "http://musicbrainz.org/artist/#{@artist.gid}.html"    
    _recommended_brands
    _recommended_artists
  end
    
  def brand
    div.header! do
      h1 'Brand: ' + @brand.title
    end
    _navigation
    _link "http://www.bbc.co.uk/programmes/#{@brand.pid}"
    _recommended_brands
    _recommended_artists
  end
  
  def my_recommendations
    div.header! do
      h1 "Recommendations for #{@profile}"
    end
    _navigation
    _link "http://last.fm/user/#{@profile}"    
    _recommended_brands
    _recommended_artists
  end
    
  private
  
  def _navigation
    ul do
      li { a('Home', :href => R(Index)) }
      li { a('Brands', :href => R(Brands)) }
      li { a('Artists', :href => R(Artists)) }
    end
  end
  
  def _link(url)
    a url, :href => url, :target => :new
  end

  def _recommended_artists
    div :style => 'float:left;clear:right;margin-right:10px' do    
      h2 'Recommended Artists'
      render_artists(@recommended_artists)
    end
  end
  
  def _recommended_brands
    div :style => 'float:left;clear:right;margin-right:10px' do    
      h2 'Recommended Brands'
      render_brands(@recommended_brands)
    end    
  end

  def render_brands(brands)
    ol do 
      for brand in brands
        li do 
          a brand.title, :href =>  R(Brand, brand.pid, nil)
          span { text " (#{brand.score})" }
        end
      end
    end
  end
  
  def render_artists(artists)
    ol do 
      for artist in artists
        li do 
          a artist.name, :href =>  R(Artist, artist.gid, nil)
          span { text " (#{artist.score})" }
        end
      end
    end
  end
  
end
