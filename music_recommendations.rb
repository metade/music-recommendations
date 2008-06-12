require 'camping'
require 'pp'
require 'rbrainz'
require 'lib/semantic_space_recommender'

include SemanticSpace

class ArtistRecommendation
  def artist
    return @rbrainz_artist unless @rbrainz_artist.nil?
    query  = MusicBrainz::Webservice::Query.new
    artist_includes = MusicBrainz::Webservice::ArtistIncludes.new(
      :url_rels     => true
    )
    @rbrainz_artist = query.get_artist_by_id(self.gid, artist_includes)
  end
end

Camping.goes :MusicRecommendations
module MusicRecommendations
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
      @artist = Models::Artist.find(mbid)
      @recommended_artists = $recommender.artist_artists(mbid)
      @recommended_brands = $recommender.artist_brands(mbid)
      render :artist
    end
  end
  
  class Brands < R '/brands'
    def get
      @brands = MusicRecommendations::recommender.brands
      render :brands
    end
  end

  class Brand < R '/brands/(.+)'
    def get(brand)
      @brand = brand
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
      h1 @artist.name
    end
    img :src => "http://67.207.137.75/recommenders/images/themeriver/artists_by_service/#{@artist.id}.png"
    text ' | '
    img :src => "http://67.207.137.75/recommenders/images/themeriver/artists_by_brand/#{@artist.id}.png"
    h2 'Recommended Artists'    
    render_artists(@recommended_artists)
    h2 'Recommended Brands'
    ol do 
      for result in @recommended_brands
        li do 
          span { a result[:brand], :href =>  R(Brand, result[:brand]) }
          span { text " (#{result[:score]})" }
        end
      end
    end
  end
    
  def brands
    div.header! do
      h1 'List of Brands'
    end
    ol do 
      for brand in @brands
        li { a brand, :href=>R(Brand, brand) }
      end
    end
  end
  
  def brand
    div.header! do
      h1 @brand
    end
    h2 'Recommended Brands'
    ol do 
      for result in @recommended_brands
        li do
          span { a result[:brand], :href =>  R(Brand, result[:brand]) }
          span { text " (#{result[:score]})" }
        end 
      end
    end
    h2 'Recommended Artists'
    render_artists(@recommended_artists)
  end
  
  private 
  
  def render_artists(artists)
    ol do 
      for result in artists
        li do 
          a result.gid, :href =>  R(Artist, result.gid)
          text ' '
          span { text " (result.score)" }
        end
      end
    end
  end
  
end
