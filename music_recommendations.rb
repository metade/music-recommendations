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
  P = 'music recommendations: error'

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
    if (format and format =~ /\.js(on)?/)
      'application/json'
    elsif (format and format=~ /\.svg/)
      'image/svg+xml'
    else
      env.ACCEPT.nil? ? (env.HTTP_ACCEPT.nil? ? 'text/html' : env.HTTP_ACCEPT) : env.ACCEPT
    end
  end
  
  # redefine render to fix issue in passenger
  def render(method)
    my_layout { self.send(method) }
  end
  
  def not_found(type, brand)
    content = my_layout { Mab.new{div.header! { h1(P);h2("#{type} #{brand} not found")} } }    
    r(404, content)
  end
  
  def construct_svg()
    x = Builder::XmlMarkup.new
    x.instruct!
    x.declare! :DOCTYPE, :svg, :PUBLIC, "-//W3C//DTD SVG 1.1//EN", "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd"
    x.svg(
      :xmlns => "http://www.w3.org/2000/svg",         
      'xmlns:xl' => "http://www.w3.org/1999/xlink", 
      :version => "1.1",
      :width => '3cm',
      :height => '3cm') do |svg|
      svg.rect(:x=>'0.5cm', :y=>'0.5cm', :width=>'2cm', :height=>'1cm')
      svg.text 'foo'
    end
    # %[<?xml version="1.0" standalone="no"?>
    #   <!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" 
    #     "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
    #   <svg width="5cm" height="4cm" version="1.1"
    #        xmlns="http://www.w3.org/2000/svg">
    #       <rect x="0.5cm" y="0.5cm" width="2cm" height="1cm"/>
    #       <rect x="0.5cm" y="2cm" width="1cm" height="1.5cm"/>
    #       <rect x="3cm" y="0.5cm" width="1.5cm" height="2cm"/>
    #       <rect x="3.5cm" y="3cm" width="1cm" height="0.5cm"/>
    #     <!-- Show outline of canvas using 'rect' element -->
    #     <rect x=".01cm" y=".01cm" width="4.98cm" height="3.98cm"
    #           fill="none" stroke="blue" stroke-width=".02cm" />
    #   </svg>
    # ]
  end
  
end

module MusicRecommendations::Controllers
  class Style < R '/style.css'
    def get      
      File.read('public/style.css')
    end
  end  
  
  class Index < R '/'
    def get
      render :index
    end
  end

  class About < R '/about'
    def get
      render :about
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
      return not_found('artist', mbid) unless MusicRecommendations::recommender.has_artist(mbid)      
      @artist = ArtistRecommendation.new(mbid)
      @recommended_artists = MusicRecommendations::recommender.artist_artists(mbid)
      @recommended_brands = MusicRecommendations::recommender.artist_brands(mbid)

      case accept(format)
        when 'application/json'
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
      return not_found('brand', brand) unless MusicRecommendations::recommender.has_brand(brand)
      @brand = BrandRecommendation.new(brand)      
      @recommended_brands = MusicRecommendations::recommender.brand_brands(brand)
      @recommended_artists = MusicRecommendations::recommender.brand_artists(brand)

      case accept(format)
        when 'application/json'
          @headers['Content-Type'] = 'application/json'
          { :brand => @brand.to_hash,
            :recommended_artists => @recommended_artists.map { |r| r.to_hash },
            :recommended_brands => @recommended_brands.map { |r| r.to_hash }, 
          }.to_json
        else render :brand
      end
    end
  end

  class MyRecommendations < R '/recommend/lastfm/([\w]*?)', '/recommend/lastfm/([\w]*?)(\.json|\.svg)'
    def get(profile, format=nil)
      if profile.blank?
        if input[:profile].blank?
          redirect R(Index)
        else
          redirect R(MyRecommendations, input[:profile])  
        end
      else
        @profile = profile
        top_artists = LastFmProfile.new(@profile).top_artists
        return not_found('last.fm profile', profile) if top_artists.nil?
        @recommended_brands = MusicRecommendations::recommender.query_brands(top_artists)
        @recommended_artists = MusicRecommendations::recommender.query_artists(top_artists)

        case accept(format)
          when 'application/json'
            @headers['Content-Type'] = 'application/json'
            { :profile => @profile,
              :recommended_artists => @recommended_artists.map { |r| r.to_hash },
              :recommended_brands => @recommended_brands.map { |r| r.to_hash }, 
            }.to_json
          when 'image/svg+xml'
            puts 'dooo'
            @headers['Content-Type'] = 'image/svg+xml'
            construct_svg()
          else render :my_recommendations          
        end
      end
    end
  end
end

module MusicRecommendations::Views

  def my_layout
    xhtml_transitional do
      head do
        title 'music recommendations'
        link :rel => 'stylesheet', :type => 'text/css', :href => R(Style), :media => 'screen'
      end
      body do
        div.container! do
          self << yield
          _navigation
        end
        _google_analytics
      end
    end
  end
  
  def index
    div.header! do
      h1 'music recommendations'
      h2 'BBC Programmes and Artists recommendations from track play-out data.'
    end
    div.content! do
      p do
        text 'BBC Programmes and Artists recommendations from '
        a 'track play-out data', :href => 'http://mashed-audioandmusic.dyndns.org/#brandsartists' 
        text ' from BBC Radio 1, Radio 2, 6Music and 1Xtra'
      end
      p do 
        text 'Start by browsing by '; a 'artists', :href => R(Artists)
        text ' or '; a 'brands', :href => R(Brands); text ', i.e. shows/djs'      
      end
      p { text 'Suggest some artists/brands based on my '; a 'Last.fm', :href => 'http://last.fm'; text ' profile:' }    
      form :method => :get, :action => '/recommend/lastfm/' do
        p do
          input :name => 'profile', :type => 'text'
          input :type => :submit
        end
      end
    end
  end
  
  def about
    div.header! do
      h1 'music recommendations: about'
      h2 'BBC Programmes and Artists recommendations from track play-out data.'      
    end
    
    h2 'the data'
    p { 'Based on playout data for Radio1, 1Xtra, Radio2 and 6Music from September 2007 until mid-June 2008. ' }
    p { 'See <a href="http://mashed-audioandmusic.dyndns.org/#brandsartists">BBC Audio & Music Interactive at Mashed 2008</a> for more details.' }

    h2 'the recommendations'
    p { 'Based on <a href="http://en.wikipedia.org/wiki/Latent_semantic_analysis">Latent Semantic Analysis</a>, a technique used in Information Retrieval. '       }

    p { 'Build a term-document matrix based on the artist play per brand: artists are terms, brands are documents.' }
    p { 'With latent semantic indexing, we map this data into a n-dimensional space that let\'s us: ' }
    ul do
      li { text 'recommend brands/artists based on another brand ' ; a '(example)', :href => R(Brand, 'b006wkqb', nil) }
      li { text 'recommend brands/artists based on another artist ' ; a '(example)', :href => R(Artist, 'ada7a83c-e3e1-40f1-93f9-3e73dbc9298a', nil) }
      li { text 'recommend brands/artists based on a last.fm profile ' ; a '(example)', :href => R(MyRecommendations, 'metade', nil) }
    end

    h2 'the recommendation engine'
    p { 'Uses the <a href="http://semanticspace.forge.ecs.soton.ac.uk">Semantic Space</a> engine developed at the <a href="http://www.ecs.soton.ac.uk">University of Southampton</a> by <a href="http://users.ecs.soton.ac.uk/jsh2/">Jonathon Hare</a>.' }

    h2 'the code'
    p { text 'Hosted on github: '; _link('http://github.com/metade/music-recommendations') }

  end
  
  def artists
    div.header! do
      h1 'music recommendations: artists'
      h2 'A random selection of artists to explore.'
    end
    ol do 
      for artist in @artists
        li { a artist.name, :href=>R(Artist, artist.gid, nil) }
      end
    end
  end
  
  def brands
    div.header! do
      h1 'music recommendations: brands'
      h2 'The BBC Radio brands indexed in our recommendation engine.'      
    end
    ol do 
      for brand in @brands
        li { a brand.title, :href=>R(Brand, brand.pid, nil) }
      end
    end
  end

  def artist
    div.header! do
      h1 'music recommendations: artist'
      h2  @artist.name
    end
    p { _link "http://musicbrainz.org/artist/#{@artist.gid}.html" }
    _recommended_brands
    _recommended_artists
  end
    
  def brand
    div.header! do
      h1 "music recommendations: brand"
      h2 @brand.title
    end
    p { _link "http://www.bbc.co.uk/programmes/#{@brand.pid}" }
    _recommended_brands
    _recommended_artists
  end
  
  def my_recommendations
    div.header! do
      h1 'music recommendations: last.fm profile'
      h2 "#{@profile}"
    end
    p { _link "http://last.fm/user/#{@profile}" }
    _recommended_brands
    _recommended_artists
  end
    
  private
  
  def _google_analytics
    return if MusicRecommendations.config[:google_analytics].blank?
    script(:type => "text/javascript") do
      text %[var gaJsHost = (("https:" == document.location.protocol) ? "https://ssl." : "http://www.");]
      text %[document.write(unescape("%3Cscript src='" + gaJsHost + "google-analytics.com/ga.js' type='text/javascript'%3E%3C/script%3E"));]
    end
    script(:type => "text/javascript") do
      text %[var pageTracker = _gat._getTracker("#{MusicRecommendations.config[:google_analytics]}");]
      text 'pageTracker._initData();'
      text 'pageTracker._trackPageview();'
    end
  end
  
  def _navigation
    div.navigation! do
      ul do
        li { a('Home', :href => R(Index)) }
        li { a('About', :href => R(About)) }
        li { a('Brands', :href => R(Brands)) }
        li { a('Artists', :href => R(Artists)) }
      end
    end
  end
  
  def _link(url)
    a url, :href => url, :target => :new
  end

  def _recommended_artists
    div.recommendations do    
      h3 'Recommended Artists'
      ol do 
        for artist in @recommended_artists
          li do 
            a artist.name, :href =>  R(Artist, artist.gid, nil)
            span { text " (#{_score(artist.score)})" }
          end
        end
      end
    end
  end
  
  def _recommended_brands
    div.recommendations do    
      h3 'Recommended Brands'
      ol do 
        for brand in @recommended_brands
          li do 
            a brand.title, :href =>  R(Brand, brand.pid, nil)
            span { text " (#{_score(brand.score)})" }
          end
        end
      end
    end    
  end
  
  def _score(score)
    "%.3f" % score
  end
  
end
