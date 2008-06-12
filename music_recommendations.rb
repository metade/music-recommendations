require 'rubygems'
require 'camping'
require 'rbrainz'
require 'lib/semantic_space_recommender'

require 'pp'

include SemanticSpace

class ArtistRecommendation
  def name
    @name ||= MusicRecommendations.artists[self.gid]
  end
end

class BrandRecommendation
  def title
    @title ||= MusicRecommendations.brands[self.pid]
  end
  def <=>(other)
    self.title <=> other.title
  end
end

Camping.goes :MusicRecommendations
module MusicRecommendations

  def self.artists
    @@artists ||= YAML.load_file('data/artists.yml')    
  end

  def self.brands
    @@brands = YAML.load_file('data/brands.yml')    
  end

  def self.recommender
    @@recommender ||= SemanticSpaceRecommender.new('data/brand_space.llss')
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
    end
  end

  class Artist < R '/artists/(.+)'
    def get(mbid)
      @artist = ArtistRecommendation.new(mbid)
      @recommended_artists = MusicRecommendations::recommender.artist_artists(mbid)
      @recommended_brands = MusicRecommendations::recommender.artist_brands(mbid)
      render :artist
    end
  end
  
  class Brands < R '/brands'
    def get
      @brands = MusicRecommendations::recommender.brands.sort
      render :brands
    end
  end

  class Brand < R '/brands/(.+)'
    def get(brand)
      @brand = BrandRecommendation.new(brand)
      @recommended_brands = MusicRecommendations::recommender.brand_brands(brand)
      @recommended_artists = MusicRecommendations::recommender.brand_artists(brand)
      render :brand
    end
  end
end

module MusicRecommendations::Views
  def layout
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
    end    
  end
  
  def artist
    div.header! do
      h1 'Artist: ' + @artist.name
    end
    div :style => 'float:left;clear:right;margin-right:10px' do    
      h2 'Recommended Brands'
      render_brands(@recommended_brands)
    end
    div :style => 'float:left;clear:right;margin-right:10px' do    
      h2 'Recommended Artists'    
      render_artists(@recommended_artists)
    end
  end
    
  def brands
    div.header! do
      h1 'List of Brands'
    end
    ol do 
      for brand in @brands
        li { a brand.title, :href=>R(Brand, brand.pid) }
      end
    end
  end
  
  def brand
    div.header! do
      h1 'Brand: ' + @brand.title
    end
    div :style => 'float:left;clear:right;margin-right:10px' do    
      h2 'Recommended Brands'
      render_brands(@recommended_brands)
    end
    div :style => 'float:left;clear:right;margin-right:10px' do    
      h2 'Recommended Artists'
      render_artists(@recommended_artists)
    end
  end
  
  private 

  def render_brands(brands)
    ol do 
      for brand in brands
        li do 
          a brand.title, :href =>  R(Brand, brand.pid)
          span { text " (#{brand.score})" }
        end
      end
    end
  end
  
  def render_artists(artists)
    ol do 
      for artist in artists
        li do 
          a artist.name, :href =>  R(Artist, artist.gid)
          span { text " (#{artist.score})" }
        end
      end
    end
  end
  
end
