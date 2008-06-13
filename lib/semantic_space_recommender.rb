require 'rubygems'
require 'semanticspace'

class ArtistRecommendation
  attr_accessor :gid, :score
  def initialize(gid, score = nil)
    self.gid, self.score = gid, score
  end
end

class BrandRecommendation
  attr_accessor :pid, :score
  def initialize(pid, score = nil)
    self.pid, self.score = pid, score
  end
end

class SemanticSpaceRecommender
  def initialize(ss_file, dimensions=44)
    @dimensions = dimensions
    @semanticspace = SemanticSpace::read_semanticspace(ss_file)
  end
  
  def brands
    return @semanticspace.list_docs(true).map { |b| BrandRecommendation.new(b) }
  end
  
  def artist_artists(mbid, limit=20)
    results = @semanticspace.search_with_term(mbid, TERM_SPACE, @dimensions)[0,limit]
    return transform_artist_results(results)
  end
  
  def artist_brands(mbid, limit=20)
    results = @semanticspace.search_with_term(mbid, TRAINING_DOCUMENT_SPACE, @dimensions)[0,limit]
    return transform_brand_results(results)
  end

  def brand_artists(brand, limit=20)
    results = @semanticspace.search_with_doc(brand, true, TERM_SPACE, @dimensions, limit)
    return transform_artist_results(results)
  end

  def brand_brands(brand, limit=20)
    results = @semanticspace.search_with_doc(brand, true, TRAINING_DOCUMENT_SPACE, @dimensions, limit)    
    return transform_brand_results(results)
  end

  private
  def transform_brand_results(results)
    return results.map { |r| BrandRecommendation.new(r.ident, r.similarity) }
  end

  def transform_artist_results(results)
    results.map { |r| ArtistRecommendation.new(r.ident, r.similarity) }
  end
end
