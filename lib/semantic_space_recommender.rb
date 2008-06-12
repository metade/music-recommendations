require 'rubygems'
require 'semanticspace'

class ArtistRecommendation
  attr_accessor :score, :gid
  def initialize(score, gid)
    self.score, self.gid = score, gid
  end
end

class SemanticSpaceRecommender
  def initialize(ss_file)
    @dimensions = 44
    @semanticspace = SemanticSpace::read_semanticspace(ss_file)
  end
  
  def brands
    return @semanticspace.list_docs(true).sort
  end
  
  def artist_artists(mbid, limit=20)
    results = @semanticspace.search_with_term(mbid, TERM_SPACE, @dimensions)[0,limit]
    return transform_artist_results(results)
  end
  
  def artist_brands(mbid, limit=20)
    results = @semanticspace.search_with_term(mbid, TRAINING_DOCUMENT_SPACE, @dimensions)[0,limit]
    return results.map do |r| 
      { :score => r.similarity, :brand => r.ident }
    end
  end

  def brand_artists(brand, limit=100)
    results = @semanticspace.search_with_doc(brand, true, TERM_SPACE, @dimensions, limit)
    return transform_artist_results(results)
  end

  def brand_brands(brand, limit=100)
    results = @semanticspace.search_with_doc(brand, true, TRAINING_DOCUMENT_SPACE, @dimensions, limit)    
    return transform_brand_results(results)
  end

  private
  def transform_brand_results(results)
    return results.map do |r| 
      { :score => r.similarity, :brand => r.ident }
    end
  end

  def transform_artist_results(results)
    results.map { |r| ArtistRecommendation.new(r.similarity, r.ident) }
  end
end
